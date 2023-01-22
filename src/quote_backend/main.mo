import Buffer "mo:base/Buffer";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Bool "mo:base/Bool";


//shared ({ caller = creator }) actor class() {  <--- TODO : Generate issues on localhost. Need to fix the problem
actor this {

  //  TYPES
  /*************************/
    public type Quote = {
      id : Nat;
      submitter : Principal;
      quote : Text;
      authorName : ?Text;
      date : Time.Time; //date of the creation
      acceptedVotingPower : Nat;
      rejectedVotingPower : Nat;
    };
    public type Errors = {
        #AuthRequired;
        #DontExist;
        #NotFound;
        #Restricted;
    };

  //  VARIABLES
  /*************************/
    //let admin : Principal = creator;  <--- TODO : To activate when the actor issue is resolved
    let admin : Principal = Principal.fromText("mt2yq-xyf2k-mnspl-ly7hm-7wiko-463cc-pqhy2-svxku-6wnxq-rzsmb-fqe");
    let devBackCanId : Principal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
    //devFrontCanId : ryjl3-tyaaa-aaaaa-aaaba-cai

    stable var stIdQuote : Nat = 0; //useless for the moment
    stable var quotesBackup : [Quote] = [];

    // TODO : Store the quoteOfTheQuotes into another canister
    stable var quoteOfTheQuotes : Quote = {
      id = 0;
      submitter = devBackCanId;
      quote = "Of all the acts, the most complete is that of building.";
      authorName = ?"Paul Valéry";
      date = Time.now();
      acceptedVotingPower = 0;
      rejectedVotingPower = 0;
    };

    /*TODO : Switch from Buffer to something less depending on the index. Could generate some issues
      An example with TrieMap instead of a Buffer
      https://github.com/samlinux/icpAsset/blob/main/src/asset_backend/main.mo
    */
    let quotes = Buffer.fromArray<Quote>(quotesBackup);
    

  //  CREATE
  /*************************/
    func create(principal : Principal, quote: Quote) : Result.Result<Text, Errors> {
      //1. Auth : Must at least be authenticated. 
      // By pass auth issues localy by testing the canister ID
      switch(Principal.isAnonymous(principal) and Principal.compare(Principal.fromActor(this), devBackCanId) != #equal) {
        case(true) {
          #err(#AuthRequired);
        };
        case(_) {
          quotes.add(quote);
          stIdQuote += 1;

          #ok("Quote " # Nat.toText(stIdQuote-1) # " created");
        };
      };
    };

    public shared ({ caller }) func submit_proposal(quote : Text, authorName : ?Text) : async Result.Result<Text, Errors> {
      create(caller, {
        id = stIdQuote;
        submitter = caller;
        quote = quote;
        authorName = authorName;
        date = Time.now();
        acceptedVotingPower = 0;
        rejectedVotingPower = 0;
      });
    };


  //  READ
  /*************************/
    public query func get_quoteOfTheQuotes() : async Quote {
      return quoteOfTheQuotes;
    };
    public query func get_proposal(index : Nat) : async ?Quote {
      quotes.getOpt(index);
    };
    /* TODO : FILTERS
      buffer.filterEntries(func(index, value) = index >= n);

      TODO : SORT
      public query func get_all_proposals(orderby : {#recent; #oldest; #accepted; #rejected}) : async [Quote] {
    */
    public query func get_all_proposals() : async [Quote] {
      Buffer.toArray(quotes);
    };
    public query func size() : async Nat {
      quotes.size();
    };

  //  UPDATE
  /*************************/
    /* This function allow the submitter or admin to update the quote. Not used for the moment.

    func update(principal : Principal, index : Nat, quote : Quote) : Result.Result<Text, Errors> {
      if(index+1 > quotes.size()) {
          return #err(#DontExist);
      };

      //1. Auth
      let isSubmitter = Principal.compare(quotes.get(index).submitter, principal) == #equal;
      let isAdmin = Principal.compare(admin, principal) == #equal;
      switch(isSubmitter or isAdmin) {
        case(true) {
          quotes.put(index, quote);
          #ok("Update done");
        };
        case(_) {
          #err(#AuthRequired);
        };
      };
    };
    */

    public shared ({ caller }) func voteAccepted(index: Nat) : async Result.Result<Text, Errors> {
      vote(index, #accepted, caller);
    };
    public shared ({ caller }) func voteRejected(index: Nat) : async Result.Result<Text, Errors> {
      vote(index, #rejected, caller);
    };
    func vote(index : Nat, choice : {#accepted; #rejected;}, caller : Principal) : Result.Result<Text, Errors> {
      //1. Skip potential issues.
      if(index+1 > quotes.size()) {
          return #err(#DontExist);
      };

      //2. Auth : Must at least be authenticated. 
      // By pass auth issues localy by testing the canister ID
      if(Principal.isAnonymous(caller)==true and Principal.compare(Principal.fromActor(this), devBackCanId) != #equal) {
          return #err(#AuthRequired);
      };

      //3. TODO get nb Motoko Bootcamp Token in the wallet
      // For the moment, init to 9
      let votingPower = 9;
      if(votingPower < 1) {
          return #err(#Restricted);
      };

      //4. Get the item and update him with the vote
      let q = quotes.get(index);
      var acceptedVotingPower = q.acceptedVotingPower;
      var rejectedVotingPower = q.rejectedVotingPower;
      switch(choice) {
        case(#accepted){
          acceptedVotingPower += votingPower;
          //5. If accepted >= 100, item is published on the homepage and is definitly deleted from the list
          if(acceptedVotingPower >= 100) {
            quoteOfTheQuotes := q;
            ignore quotes.remove(index);
            return #ok("{Message: \"Approved ! Long life to this quote.\"}");
          };
        };
        case(#rejected) {
          rejectedVotingPower += votingPower;
          //6. If reject >= 100, delete definitly the item
          if(rejectedVotingPower >= 100) {
            ignore quotes.remove(index);
            return #ok("Definitively rejected");
          };
        };
      };

      let qUpdated = {
        id = q.id;
        submitter = q.submitter;
        quote = q.quote;
        authorName = q.authorName;
        date = q.date;
        acceptedVotingPower = acceptedVotingPower;
        rejectedVotingPower = rejectedVotingPower;
      };

      //6. replace the old version
      quotes.put(index, qUpdated);
      #ok(Nat.toText(acceptedVotingPower) # "-" # Nat.toText(rejectedVotingPower));
    };

  //  DELETE
  /*************************/
    public shared ({ caller }) func delete(id : Nat) : async Result.Result<Text, Errors> {
      if(id+1 > quotes.size()) {
          return #err(#DontExist);
      };

      //1. Auth
      let isSubmitter = Principal.compare(quotes.get(id).submitter, caller) == #equal;
      let isAdmin = Principal.compare(admin, caller) == #equal;
      switch(isSubmitter or isAdmin) {
        case(true) {
          ignore quotes.remove(id);
          #ok("Delete done");
        };
        case(_) {
          #err(#AuthRequired);
        };
      };
    };


  //  HELPERS
  /*************************/
    public shared ({ caller }) func init() : async Result.Result<Text, Errors> {
      switch(Principal.compare(admin, caller)) {
        case(#equal) {
          quotes.add({
            id = stIdQuote;
            submitter = Principal.fromText("gol5v-c3bwr-bzngk-u7z23-lkytf-blb2a-zx27b-xvmuw-oebyx-4ii2j-4qe");
            quote = "Sic parvis magna";
            authorName = ?"Sir Francis Drake"; //Bergerze
            date = Time.now();
            acceptedVotingPower = 0;
            rejectedVotingPower = 0;
          });
          stIdQuote += 1;
          
          quotes.add({
            id = stIdQuote;
            submitter = Principal.fromText("mt2yq-xyf2k-mnspl-ly7hm-7wiko-463cc-pqhy2-svxku-6wnxq-rzsmb-fqe");
            quote = "Our deepest fear is not that we are inadequate,"
                    # "\r\nOur deepest fear is that we are powerful beyond measure."
                    # "\r\n"
                    # "\r\nIt is our light, not our darkness, that most frightens us."
                    # "\r\nYour playing small does not serve the world."
                    # "\r\n"
                    # "\r\nThere is nothing enlightened about shrinking"
                    # "\r\nso that other people won’t feel insecure around you."
                    # "\r\n"
                    # "\r\nWe were all meant to shine as children do."
                    # "\r\nIt’s not just in some of us, it’s in everyone."
                    # "\r\n"
                    # "\r\nAnd, as we let our own light shine, we consciously give"
                    # "\r\nother people permission to do the same."
                    # "\r\n"
                    # "\r\nAs we are liberated from our fear,"
                    # "\r\nour presence automatically liberates others."
                    ;
            authorName = ?"Marianne Williamson"; //Atia
            date = Time.now();
            acceptedVotingPower = 0;
            rejectedVotingPower = 0;
          });
          stIdQuote += 1;

          #ok("Initialisation done with a total of " # Nat.toText(quotes.size()) # " quotes");
        };
        case(_) {
          #err(#AuthRequired);
        };
      }
    };

    public shared ({caller}) func whoIsConnected() : async {isAuth : Bool; principal : Text;} {
      return {isAuth = Principal.isAnonymous(caller)==false; principal = Principal.toText(caller)};
    };

    system func preupgrade() {
      quotesBackup := Buffer.toArray(quotes);
    };
    system func postupgrade() {
      quotesBackup := [];
    };

    
  //  EXAMPLES
  /*************************/
      /* To call a function in the terminal :
        dfx canister call quote_backend create '(
          record {
            submitter = principal "'$(dfx identity get-principal)'";
            quote = "Sic parvis magna";
            authorName = opt ("Sir Francis Drake");
          })'
      */
}