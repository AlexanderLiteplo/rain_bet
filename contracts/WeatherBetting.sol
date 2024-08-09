// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WeatherBetting {
    enum BetType {WillRain, WillNotRain}

    uint256 private betCount;
    uint256 private lastExecutedBet;

    struct Bet {
        uint256 etheAmount;
        address bettor;
        BetType betType;
        uint256 date;
        bool isActive;
    }

    // key should be the day for example Jan 6th 2021
    mapping(uint256 => Bet[]) private bets;

    event BetsReset();
    event BetPlaced(uint256, uint256, BetType, address, uint256);
    event BetsSettled(uint256, BetType, uint256, uint256);
    event WinningsPaid(address, uint256);

    constructor() {
        betCount = 0;
        lastExecutedBet = 0;
    }

    // @param _date is a uint256 mmddyyyy and it must be in the future
    function placeBet(BetType _betType, uint256 _date) external payable {
        require(msg.value > 0, "Bet must be larger than zero");
        
        betCount++;
        bets[_date].push(Bet({
            etheAmount: msg.value,
            bettor: msg.sender,
            betType: _betType,
            date: _date,
            isActive: true
        }));

        emit BetPlaced(betCount, msg.value, _betType, msg.sender, _date);
    }

    function checkIfItRained(uint256 _betDate) public {
        bool itRained = true;

        if (itRained) settleBets(BetType.WillRain, _betDate);
        else if (!itRained) settleBets(BetType.WillNotRain, _betDate);
    }

    // @param _betDate is the day of the bet that needs to be settled
    function settleBets(BetType winningType, uint256 _betDate) private {
        // this should execute at the end of the day
        Bet[] storage todaysBets = bets[_betDate];
        uint256 winBetsEthe = 0;
        uint256 numWinBets = 0;
        uint256 loseBetsEthe = 0;
        uint256 numLoseBets = 0;

        // go through all bets starting with last executed bet
        for (uint256 i = 0; i <= betCount; i++) {
            if (todaysBets[i].date == _betDate && todaysBets[i].isActive) {
                if (todaysBets[i].betType == winningType) {
                    winBetsEthe += todaysBets[i].etheAmount;
                    numWinBets++;
                }
                if (todaysBets[i].betType != winningType) {
                    loseBetsEthe += todaysBets[i].etheAmount;
                    numLoseBets++;
                }
            }
        }

        uint256[] memory winningBets = new uint256[](numWinBets);
        uint256[] memory losingBets = new uint256[](numLoseBets);
        uint256 winIndex = 0;
        uint256 loseIndex = 0;

        // go through all bets starting with last executed bet
        for (uint256 i = 0; i <= betCount; i++) {
            if (todaysBets[i].date == _betDate && todaysBets[i].isActive) {
                if (todaysBets[i].betType == winningType) {
                    winningBets[winIndex] = i;
                    winIndex++;
                } else {
                    losingBets[loseIndex] = i;
                    loseIndex++;
                }
                todaysBets[i].isActive = false;
            }
        }

        // Distribute winnings
        for (uint256 i = 0; i < winningBets.length; i++) {
            uint256 betIndex = winningBets[i];

            // Calculate the proportion of the total winning bets this bet represents
            uint256 proportion = todaysBets[betIndex].etheAmount * 1e18 / winBetsEthe;
            
            // Calculate the winnings based on this proportion
            uint256 winnings = (loseBetsEthe * proportion) / 1e18;
            
            // Add the original bet amount to the winnings
            uint256 totalPayout = winnings + todaysBets[betIndex].etheAmount;
            
            // Transfer the total payout to the winning bettor
            payable(todaysBets[betIndex].bettor).transfer(totalPayout);

            // Emit an event for this payout
            emit WinningsPaid(todaysBets[betIndex].bettor, totalPayout);
        }

        emit BetsSettled(_betDate, winningType, winBetsEthe, loseBetsEthe);
    }

    function deleteOldBets(uint256 _date) private {
        delete bets[_date];
    }

}