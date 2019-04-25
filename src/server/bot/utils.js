module.exports = {
  betToString(bet) {
    return `${bet.index}: ${bet.player} | ${bet.round} | ${bet.number >= 10 ? bet.number : '0' + bet.number} | ${bet.isOver ? 'Over ' : 'Under'} | ${bet.amount}`;
  }
}