pragma solidity 0.5.0;

import "./PoolContract.sol";
import "./SafeMath.sol";

contract MaxBetContract is PoolContract {
    using SafeMath for uint;

    struct Bet {
        uint index;
        uint number;
        bool isOver;
        uint amount;
        address payable player;
        uint round;
        uint luckyNumber;
        uint gameType;
        uint seed;
        bool isFinished;
    }

    struct Random {
        bytes32 commitment;
        uint secret;         // greater than zero
    }

    struct PlayerAmount {
        uint totalBet;
        uint totalPayout;
    }

    // SETTING
    uint constant public NUMBER_BLOCK_OF_LEADER_BOARD = 43200;
    uint constant public MAX_LEADER_BOARD = 10;
    uint constant public MINIMUM_BET_AMOUNT = 0.1 ether;
    uint constant public HOUSE_EDGE = 2;
    uint public PRIZE_PER_BET_LEVEL = 10;

    // Just for display on app
    uint public totalBetOfGame = 0;
    uint public totalWinAmountOfGame = 0;

    Random[] public rands;
    mapping(uint => uint) public roundToRandIndex; // block.number => index of rands
    uint public randIndexForNextRound = 0;

    // Properties for game
    Bet[] public bets; // All bets of player
    uint public numberOfBetWaittingDraw = 0; // Count bet is not finished
    uint public indexOfDrawnBet = 1; // Point to start bet, which need to check finish. If not finish, finish it to release lock balance
    mapping(address => uint[]) public betsOf; // Store all bet of player
    mapping(address => PlayerAmount) public amountOf; // Store all bet of player

    mapping(address => bool) public croupiers;

    // Preperties for leader board
    uint[] public leaderBoardRounds; // block will sent prize
    mapping(uint => mapping(address => uint)) public totalBetOfPlayers; //Total bet of player in a round of board: leaderBoardBlock => address => total amount
    mapping(uint => address[]) public leaderBoards; //Leader board of a round of board: leaderBoardBlock => array of top players
    mapping(uint => mapping(address => uint)) public leaderBoardWinners; // round => player => prize

    event TransferWinner(address winner, uint betIndex, uint amount);
    event TransferLeaderBoard(address winner, uint round, uint amount);
    event NewBet(address player, uint round, uint gameType, uint index, uint number, bool isOver, uint amount);
    event DrawBet(address player, uint round, uint seedNumber, uint index, uint number, bool isOver, uint amount, bool isFinished, uint luckyNumber);

    constructor(address payable _operator, address _croupier) public {
        operator = _operator;
        croupiers[_croupier] = true;
        leaderBoardRounds.push(block.number + NUMBER_BLOCK_OF_LEADER_BOARD);

        rands.push(Random({
            commitment: bytes32(0),
            secret: 0
        }));
        randIndexForNextRound = 1;

        bets.push(Bet({
            number: 0,
            isOver: false,
            amount: 0,
            player: address(0x0),
            round: 0,
            isFinished: true,
            luckyNumber: 0,
            gameType: 0,
            index: 0,
            seed: 0
        }));
    }

    modifier onlyCroupier() { require(croupiers[msg.sender], "not croupier"); _; }

    /**
    GET FUNCTION
     */

    function getLastBetIndex(address add) public view returns (uint) {
        if (betsOf[add].length == 0) return 0;
        return betsOf[add][betsOf[add].length - 1];
    }

    function getLastRand() public view  returns (bytes32 commitment, uint secret, uint index) {
        index = rands.length - 1;
        commitment = rands[index].commitment;
        secret = rands[index].secret;
    }

    function getCurrentLeaderBoard() public view returns (uint currentRound, address[] memory players) {
        currentRound = leaderBoardRounds[leaderBoardRounds.length - 1];
        players = leaderBoards[leaderBoardRounds[leaderBoardRounds.length - 1]];
    }

    function getRoundLeaderBoard(uint index, bool isFromTail) public view returns (uint) {
        if (isFromTail) {
            return leaderBoardRounds[leaderBoardRounds.length - index - 1];
        }
        else {
            return leaderBoardRounds[index];
        }
    }

    function totalNumberOfBets(address player) public view returns(uint) {
        if (player != address(0x00)) return betsOf[player].length;
        else return bets.length;
    }

    function numberOfLeaderBoardRounds() public view returns (uint) {
        return leaderBoardRounds.length;
    }

    /**
    BET RANGE
     */

    function calculatePrizeForBet(uint betAmount) public view returns (uint) {
        uint bal = super.balanceForGame(betAmount);
        uint prize = 1 ether;
        if      (bal > 1000000 ether) prize = 500 ether;
        else if (bal >  500000 ether) prize = 200 ether;
        else if (bal >  200000 ether) prize = 100 ether;
        else if (bal >   50000 ether) prize =  50 ether;
        else if (bal >   20000 ether) prize =  20 ether;
        else if (bal >    2000 ether) prize =  10 ether;
        else                          prize =   5 ether;

        if (PRIZE_PER_BET_LEVEL > 100) return prize.mul(10);
        else if (PRIZE_PER_BET_LEVEL < 10) return prize;
        else return prize.mul(PRIZE_PER_BET_LEVEL).div(10);
    }

    function betRange(uint number, bool isOver, uint amount) public view returns (uint min, uint max) {
        uint currentWinChance = calculateWinChance(number, isOver);
        uint prize = calculatePrizeForBet(amount);
        min = MINIMUM_BET_AMOUNT;
        max = prize.mul(currentWinChance).div(100);
        max = max > MINIMUM_BET_AMOUNT ? max : MINIMUM_BET_AMOUNT;
    }

    /**
    BET
     */

    function calculateWinChance(uint number, bool isOver) private pure returns (uint) {
        return isOver ? 99 - number : number;
    }

    function calculateWinAmount(uint number, bool isOver, uint amount) private pure returns (uint) {
        return amount.mul(100 - HOUSE_EDGE).div(calculateWinChance(number, isOver));
    }

    function addToLeaderBoard(address player, uint amount) private {
        uint round = leaderBoardRounds[leaderBoardRounds.length - 1];
        address[] storage boards = leaderBoards[round];
        mapping(address => uint) storage totalBets = totalBetOfPlayers[round];

        totalBets[player] = totalBets[player].add(amount);
        if (boards.length == 0) {
            boards.push(player);
        }
        else {
            // If found the player on list, set minIndex = MAX_LEADER_BOARD as a flag
            // to check it. if not found the play on array, minIndex is always
            // less than MAX_LEADER_BOARD
            uint minIndex = 0;
            for (uint i = 0; i < boards.length; i++) {
                if (boards[i] == player) {
                    minIndex = MAX_LEADER_BOARD;
                    break;
                } else if (totalBets[boards[i]] < totalBets[boards[minIndex]]) {
                    minIndex = i;
                }
            }
            if (minIndex < MAX_LEADER_BOARD) {
                if (boards.length < MAX_LEADER_BOARD) {
                    boards.push(player);
                } else if (totalBets[boards[minIndex]] < totalBets[player]) {
                    boards[minIndex] = player;
                }
            }
        }
    }

    /**
    DRAW WINNER
    */

    function checkWin(uint number, bool isOver, uint luckyNumber) private pure returns (bool) {
         return (isOver && number < luckyNumber) || (!isOver && number > luckyNumber);
    }

    function getLuckyNumber(uint betIndex) private view returns (uint) {
        Bet memory bet = bets[betIndex];

        if (roundToRandIndex[bet.round] == 0) return 0;
        if(bet.round >= block.number) return 0;

        Random memory rand = rands[roundToRandIndex[bet.round]];
        if (rand.secret == 0) return 0;

        uint blockHash = uint(blockhash(bet.round));
        if (blockHash == 0) {
            blockHash = uint(blockhash(block.number - 1));
        }
        return 100 + ((rand.secret ^ bet.seed ^ blockHash) % 100);
    }

    /**
    WRITE & PUBLIC FUNCTION
     */

    //A function only called from outside should be external to minimize gas usage
    function placeBet(uint number, bool isOver, uint gameType, uint seed) public payable notStopped {
        uint round = block.number;

        uint betAmount = msg.value;

        uint minAmount;
        uint maxAmount;
        uint lastBetIdx = getLastBetIndex(msg.sender);
        (minAmount, maxAmount)= betRange(number, isOver, betAmount);

        require(rands.length > 0 && randIndexForNextRound < rands.length, "The game have not ready");
        require(minAmount > 0 && maxAmount > 0, "stopped");
        require(isOver ? number >= 4 && number <= 98 : number >= 1 && number <= 95, "wrong number");
        require(minAmount <= betAmount && betAmount <= maxAmount, "wrong amount");
        require(bets[lastBetIdx].isFinished, "last bet has not finished yet");

        if (roundToRandIndex[round] == 0) {
            roundToRandIndex[round] = randIndexForNextRound;
            randIndexForNextRound += 1;
        }

        uint winAmount = calculateWinAmount(number, isOver, betAmount);
        super.newBet(betAmount, winAmount);

        uint index = bets.length;

        totalBetOfGame += betAmount;

        betsOf[msg.sender].push(index);
        numberOfBetWaittingDraw++;
        bets.push(Bet({
            index: index,
            number: number,
            isOver: isOver,
            amount: betAmount,
            player: msg.sender,
            round: round,
            isFinished: false,
            luckyNumber: 0,
            gameType: gameType,
            seed: seed
            }));
        addToLeaderBoard(msg.sender, betAmount);
        emit NewBet(msg.sender, round, gameType, index, number, isOver, betAmount);
    }

    function refundBet(address payable add) external {
        uint betIndex = getLastBetIndex(add);
        Bet storage bet = bets[betIndex];
        require(!bet.isFinished && bet.player == add && block.number - bet.round > 150, "cannot refund");

        uint winAmount = calculateWinAmount(bet.number, bet.isOver, bet.amount);

        add.transfer(bet.amount);
        super.finishBet(bet.amount, winAmount);

        numberOfBetWaittingDraw--;
        bet.isFinished = true;
        bet.amount = 0;
    }

    function sendPrizeToWinners(uint round, address payable win1, address payable win2, address payable win3) private {
        if (win1 == address(0x00)) return;

        uint prize1 = 0;
        uint prize2 = 0;
        uint prize3 = 0;

        if (win3 != address(0x00)) prize3 = totalPrize.mul(2).div(10);
        if (win2 != address(0x00)) prize2 = totalPrize.mul(3).div(10);
        prize1 = totalPrize.sub(prize2).sub(prize3);

        if (prize3 > 0) {
            super.sendPrizeToWinner(win3, prize3);
            leaderBoardWinners[round][win3] = prize3;
            emit TransferLeaderBoard(win3, round, prize3);
        }
        if (prize2 > 0) {
            super.sendPrizeToWinner(win2, prize2);
            leaderBoardWinners[round][win2] = prize2;
            emit TransferLeaderBoard(win2, round, prize2);
        }
        super.sendPrizeToWinner(win1, prize1);
        emit TransferLeaderBoard(win1, round, prize1);
        leaderBoardWinners[round][win1] = prize1;

    }

    function finishLeaderBoard() public {
        uint round = leaderBoardRounds[leaderBoardRounds.length - 1];
        address[] storage boards = leaderBoards[round];
        mapping(address => uint) storage totalBets = totalBetOfPlayers[round];

        if (round > block.number) return;
        if (boards.length == 0) return;

        if (totalPrize <= 0) {
            leaderBoardRounds.push(block.number + NUMBER_BLOCK_OF_LEADER_BOARD);
            return;
        }

        // boards have maximum 3 elements.
        for (uint i = 0; i < boards.length; i++) {
        for (uint j = i + 1; j < boards.length; j++) {
            if (totalBets[boards[j]] > totalBets[boards[i]]) {
                address temp = boards[i];
                boards[i] = boards[j];
                boards[j] = temp;
            }
        }
        }

        address w1 = boards[0];
        address w2 = boards.length >= 1 ? boards[1] : address(0x00);
        address w3 = boards.length >= 2 ? boards[2] : address(0x00);

        sendPrizeToWinners(round,
            address(uint160(w1)),
            address(uint160(w2)),
            address(uint160(w3)));
        leaderBoardRounds.push(block.number + NUMBER_BLOCK_OF_LEADER_BOARD);
    }

    /**
    FOR OPERATOR
     */

    function settleBet(uint n) public onlyCroupier {
        if (indexOfDrawnBet >= bets.length) return;

        n = n > 0 ? n : bets.length - indexOfDrawnBet;
        for (uint i = 0; i < n && indexOfDrawnBet < bets.length; i++) {
            Bet storage bet = bets[indexOfDrawnBet];

            uint r = bet.round;
            if (r >= block.number) return;

            indexOfDrawnBet++;
            if (bet.isFinished) continue;

            uint luckyNum = getLuckyNumber(bet.index);
            if (luckyNum == 0) {
                indexOfDrawnBet--;
                return;
            }
            luckyNum -= 100;

            uint winAmount = calculateWinAmount(bet.number, bet.isOver, bet.amount);

            bet.luckyNumber = luckyNum;
            bet.isFinished = true;
            numberOfBetWaittingDraw--;

            if (checkWin(bet.number, bet.isOver, luckyNum)) {
                totalWinAmountOfGame += winAmount;
                bet.player.transfer(winAmount);
                super.finishBet(bet.amount, winAmount);
                amountOf[bet.player].totalBet += bet.amount;
                amountOf[bet.player].totalPayout += winAmount;
                emit TransferWinner(bet.player, bet.index, winAmount);
            } else {
                super.finishBet(bet.amount, winAmount);
                amountOf[bet.player].totalBet += bet.amount;
            }
            super.shareProfitForPrize(bet.amount);
            emit DrawBet(bet.player, bet.round, bet.gameType, bet.index, bet.number, bet.isOver, bet.amount, bet.isFinished, bet.luckyNumber);
        }
    }

    function commit(bytes32 _commitment) public onlyCroupier {
        require(bytes32(0) != _commitment, "commitment is invalid");
        require(bytes32(0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563) != _commitment, "Secret should not be 0");
        rands.push(Random({
            commitment: _commitment,
            secret: 0
        }));
    }

    function reveal(uint round, uint _secret) public onlyCroupier {
        require(roundToRandIndex[round] > 0, "Invalid round");

        Random storage rand = rands[roundToRandIndex[round]];
        require(round < block.number, "Cannot settle in this block");
        require(keccak256(abi.encodePacked((_secret))) == rand.commitment, "Submitted secret is not matching with the commitment");

        rand.secret = _secret;
    }

    // Should use hight gasPrice
    function nextTick(uint round, uint secret, bytes32 commitment, uint numberFinish) external onlyCroupier {
        if (round > 0 && secret > 0) {
            reveal(round, secret);
        }
        if (commitment != bytes32(0)) {
            commit(commitment);
        }
        settleBet(numberFinish);
        super.takeProfitInternal(false, 0);
        finishLeaderBoard();
    }

    function moveRandIndexForNextRound(uint newIndex) public onlyCroupier {
        require(newIndex >= randIndexForNextRound, "New index must be greater than old index");
        randIndexForNextRound = newIndex;
    }

    function setCroupier(address add, bool isCroupier) external onlyOperator {
        croupiers[add] = isCroupier;
    }

    function setPrizeLevel(uint level) external onlyOperator {
        PRIZE_PER_BET_LEVEL = level;
    }
}