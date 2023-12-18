<img src="https://i.imgur.com/xkTrLGh.png">

## Jackpot.ton

Contract address: `EQD2PxztdUiYWLyA-9GkBY0fFtebIStuVxXggJ5z_3LuKb9T`<br>

Website link: https://jackpot-ton.com<br>

You can send transfers to `jackpot.ton`

By sending TON to the contract address, the sender joins the current round.

Your transfer will be validated in several steps:
1. `Transfer value >= minimum bet.`
2. `Each round allows one transfer from one address.`
3. `Transfer without comments.`

The amount of tickets the sender receives in this round is proportional to the amount of TON sent.

`tickets = nanoTONs / 100000`

- `1 TON = 1000000000 nanoTONs = 10000 tickets.`
- `3.58293923 TON = 3582939230 nanoTONs = 35829 tickets.`

During transaction processing, the smart contract subtracts 0.02 TON (average gas cost) from the transaction amount and adds the result to the jackpot.
`(Transfer of 1 ton = 1 - 0.02 = 0.98 = 9800 tickets)`

The contract must gather the required number of participants to complete a round and select a winner.

## Example of smart contract logic:

* Round start (min_bet = 1 TON, max_players = 3)
* - `Player1 bets 2 TON (receives tickets from 1 to 20000)`
* - `Player2 bets 1 TON (receives tickets from 20001 to 30000)`
* - `Player3 bets 1 TON (receives tickets from 30001 to 40000)`
* The maximum number of players has been reached
* The contract generates a random number from 0 to 40000.
* The random number is 28439 = Player2 won.
* - `Player2 receives 1 TON (original bet) + (3 TON - contract fee %).` The contract only takes a fee from winnings.
* The contract cleans up.
* A new round begins.

You can only blame the randomizer for not winning.
[randomizeLt](https://docs.ton.org/develop/smart-contracts/guidelines/random-number-generation#simply-use-randomize_lt).

If you are curious about the ticket number of the last winner, the contract has a function called get_winner_ticket.

The contract owner has the following abilities:
1. `Change max players in round. (from 1 to 100)`
2. `Change min bet. (from 1 to 100 TONs)`
3. `Change fee percent. (from 1 to 5)` 5% is max.
4. `Transferring funds from a smart contract balance.`

**It is important to note that the owner cannot transfer funds that are in an active round. Only funds remaining on the contract balance as fees can be transferred.**

## License

MIT
