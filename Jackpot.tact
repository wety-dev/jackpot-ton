import "@stdlib/deploy";

struct Player {
    address: Address;
    bet: Int as coins;
    ticket_start: Int as uint64;
    ticket_end: Int as uint64;
}

struct Winner {
    address: Address;
    ticket: Int as uint64;
}

message OwnerCashout {
    value: Int as coins;
}

message SetPlayersMax {
    new_players_max: Int as uint8;
}

message SetBetMin {
    new_bet_min: Int as coins;
}

message SetFeePercent {
    fee_percent: Int as uint8;
}

contract Jackpot with Deployable {

    owner: Address;
    fee_percent: Int as uint8 = 5;
    bet_min: Int as coins;
    players_max: Int as uint8;
    players_current: Int as uint8 = 0;
    players_list: map<Address, Player>;
    players_nav_list: map<Int, Address>; // List used to navigate around dictionary.

    locked_balance: Int as coins = 0;
    winner_ticket: Int as uint64 = 0;

    init(owner: Address, bet_min: Int, players_max: Int) {
        self.owner = owner;
        self.bet_min = bet_min;
        self.players_max = players_max;
    }

    receive(msg: OwnerCashout) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Access denied.");
        require(msg.value > 0, "Invalid cashout value");
        require((myBalance() - (self.locked_balance + ton("5"))) > msg.value, "Invalid value!");

        send(SendParameters{
            to: self.owner,
            value: msg.value,
            mode: SendIgnoreErrors,
            bounce: true,
            body: "Owner cashout!".asComment()
        });
    }

    receive(msg: SetPlayersMax) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Access denied.");
        require(msg.new_players_max <= 100, "Too many players");
        require(msg.new_players_max > 0, "Too few players");
        self.players_max = msg.new_players_max;
    }

    receive(msg: SetBetMin) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Access denied.");
        require(msg.new_bet_min <= ton("100"), "Too big min bet");
        require(msg.new_bet_min > 0, "Too low min bet");
        self.bet_min = msg.new_bet_min;
    }

    receive(msg: SetFeePercent) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Access denied.");
        require(msg.fee_percent <= 5, "Too greedy");
        require(msg.fee_percent > 1, "Take something from this");
        self.fee_percent = msg.fee_percent;
    }

    receive(){
        let ctx: Context = context();
        
        require(self.IsPlayerInGame(ctx.sender) == false, "Error: This player in game already!");
        require(ctx.value >= self.bet_min, "Error: Value < Minimum_bet!");

        let from_ticket: Int = (self.locked_balance + ton("0.0001")) / 100000; // Example: User bets 50 TON. = 50000000000 nanoTons. / 100000 = 500000 tickets. + ton(0.001) = 500001 (so tickets wont collide on users.)
        self.locked_balance = self.locked_balance + (ctx.value - ton("0.02")); // Here we take approximate gas consumption from transfer value.
        let to_ticket: Int = self.locked_balance / 100000; //End ticket number.

        self.players_list.set(ctx.sender, Player{address: ctx.sender, bet: ctx.value, ticket_start: from_ticket, ticket_end: to_ticket}); //Add Player to main map.
        self.players_current = self.players_current + 1;
        self.players_nav_list.set(ctx.sender.asSlice().hash(), ctx.sender); //Add user to nav map.

        if(self.players_current >= self.players_max){ // Even if players_current changed to lower value, raffle will start with next transaction. Last transaction will be included to raffle.

            //Raffle logic

            nativeRandomizeLt(); // May lt be with you.

            let totalTickets: Int = self.locked_balance / 100000;
            let winnerticket: Int = random(0, totalTickets);
            self.winner_ticket = winnerticket;

            let foundPair: DictPair? = DictGetMin(self.players_nav_list);
            let winner: Winner = Winner{address: self.owner, ticket: totalTickets};

            while(foundPair != null){

                let player: Player? = self.players_list.get((foundPair!!).value);
                
                let num: Int = abs(winnerticket - (player!!).ticket_start);
                if(num < winner.ticket){
                    winner.address = (player!!).address;
                    winner.ticket = num;
                }

                num = abs(winnerticket - (player!!).ticket_end);
                if(num < winner.ticket){
                    winner.address = (player!!).address;
                    winner.ticket = num;
                }

                foundPair = DictGetNext(self.players_nav_list, (foundPair!!).key);
            }

            let playerWinner: Player? = self.players_list.get(winner.address);

            send(SendParameters {
                to: (playerWinner!!).address,
                value: (((self.locked_balance - (playerWinner!!).bet) / 100) * (100 - self.fee_percent)) + (playerWinner!!).bet, // Here we take fee_percent, only from winnings. Original bet will be returned to player. (bet + (winnings - fee))
                mode: SendIgnoreErrors,
                bounce: false,
                body: ("Jackpot.ton Winner! Congrats!").asComment()
            });

            self.CleanUp();
        }
    }

    fun IsPlayerInGame(address: Address) : Bool {
        if(self.players_list.get(address) != null){
            return true;
        }
        else{
            return false;
        }
    }

    fun CleanUp() {
        self.players_list = emptyMap();
        self.players_nav_list = emptyMap();
        self.players_current = 0;
        self.locked_balance = 0;
    }

    get fun get_bet_min() : Int {
        return self.bet_min;
    }

    get fun get_players_max() : Int {
        return self.players_max;
    }

    get fun get_players_current(): Int {
        return self.players_current;
    }

    get fun get_locked_balance(): Int {
        return self.locked_balance;
    }

    get fun get_winner_ticket(): Int {
        return self.winner_ticket;
    }

    get fun get_fee_percent(): Int {
        return self.fee_percent;
    }
}

struct NativePair {
    key: Int?;
    value: Address?;
    flag: Bool;
}

struct DictPair {
    key: Int;
    value: Address;
}

@name(idict_get_min?)
native native_dict_get_min(dict: map<Int, Address>, length: Int): NativePair;

fun DictGetMin(dict: map<Int, Address>): DictPair? {
    let pair: NativePair = native_dict_get_min(dict, 257);
    if (pair.flag) {
        return DictPair{key: pair.key!!, value: pair.value!!};
    }
    else {
        return null;
    }
}

@name(idict_get_next?)
native native_dict_get_next(dict: map<Int, Address>, length: Int, pivot: Int): NativePair;

fun DictGetNext(dict: map<Int, Address>, pivot: Int): DictPair? {
    let pair: NativePair = native_dict_get_next(dict, 257, pivot);
    if (pair.flag) {
        return DictPair{key: pair.key!!, value: pair.value!!};
    }
    else {
        return null;
    }
}