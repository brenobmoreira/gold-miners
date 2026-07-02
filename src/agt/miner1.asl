// miner agent

{ include("$jacamoJar/templates/common-cartago.asl") }

/*
 * By Joao Leite
 * Based on implementation developed by Rafael Bordini, Jomi Hubner and Maicon Zatelli
 */

/* beliefs */
last_dir(null). // the last movement I did
free.
score(0). // how many gold pieces I have dropped at the depot
capacity(2). // max known gold in my backlog before I ask my partner for help

/* rules */
/* team membership (Phase 1: derived from the agent name).
 * Team A = {miner1, miner2}, Team B = {miner3, miner4}. */
// team is a string so it matches the reserved(X,Y,Team) property published
// by the GoldRegistry artifact (CArtAgO maps a Java String to a Jason string)
team("teamA") :- .my_name(miner1).
team("teamA") :- .my_name(miner2).
team("teamB") :- .my_name(miner3).
team("teamB") :- .my_name(miner4).

// my partner is the other member of my team
partner(miner2) :- .my_name(miner1).
partner(miner1) :- .my_name(miner2).
partner(miner4) :- .my_name(miner3).
partner(miner3) :- .my_name(miner4).

// each partner owns half of the map (by column X) to reduce wasted crossings
region(left)  :- .my_name(miner1).
region(left)  :- .my_name(miner3).
region(right) :- .my_name(miner2).
region(right) :- .my_name(miner4).

in_my_region(X) :- region(left)  & gsize(_,W,_) & X <  W/2.
in_my_region(X) :- region(right) & gsize(_,W,_) & X >= W/2.


/* When free, agents wonder around. This is encoded with a plan that executes
 * when agents become free (which happens initially because of the belief "free"
 * above, but can also happen during the execution of the agent (as we will see below).
 *
 * The plan simply gets two random numbers within the scope of the size of the grid
 * (using an internal action jia.random), and then calls the subgoal go_near. Once the
 * agent is near the desired position, if free, it deletes and adds the atom free to
 * its belief base, which will trigger the plan to go to a random location again.
 */

+free : gsize(_,W,H) & jia.random(RX,W-1) & jia.random(RY,H-1)
   <-  .print("I am going to go near (",RX,",", RY,")");
       !go_near(RX,RY).
+free  // gsize is unknown yet
   <- .wait(100); -+free.

/* When the agent comes to believe it is near the location and it is still free,
 * it updates the atom "free" so that it can trigger the plan to go to a random
 * location again.
 */
+near(X,Y) : free <- -+free.



/* The following plans encode how an agent should go to near a location X,Y.
 * Since the location might not be reachable, the plans succeed
 * if the agent is near the location, given by the internal action jia.neighbour,
 * or if the last action was skip, which happens when the destination is not
 * reachable, given by the plan next_step as the result of the call to the
 * internal action jia.get_direction.
 * These plans are only used when exploring the grid, since reaching the
 * exact location is not really important.
 */

+!go_near(X,Y) : free
  <- -near(_,_);
     -last_dir(_);
     !near(X,Y).


// I am near to some location if I am near it
+!near(X,Y) : (pos(AgX,AgY) & jia.neighbour(AgX,AgY,X,Y))
   <- .print("I am at ", "(",AgX,",", AgY,")", " which is near (",X,",", Y,")");
      +near(X,Y).

// I am near to some location if the last action was skip
// (meaning that there are no paths to there)
+!near(X,Y) : pos(AgX,AgY) & last_dir(skip)
   <- .print("I am at ", "(",AgX,",", AgY,")", " and I can't get to' (",X,",", Y,")");
      +near(X,Y).

+!near(X,Y) : not near(X,Y)
   <- !next_step(X,Y);
      !near(X,Y).
+!near(X,Y) : true
   <- !near(X,Y).


/* These are the plans to have the agent execute one step in the direction of X,Y.
 * They are used by the plans go_near above and pos below. It uses the internal
 * action jia.get_direction which encodes a search algorithm.
 */

+!next_step(X,Y) : pos(AgX,AgY) // I already know my position
   <- jia.get_direction(AgX, AgY, X, Y, D);
      -+last_dir(D);
      D.
+!next_step(X,Y) : not pos(_,_) // I still do not know my position
   <- !next_step(X,Y).
-!next_step(X,Y) : true  // failure handling -> start again!
   <- -+last_dir(null);
      !next_step(X,Y).


/* The following plans encode how an agent should go to an exact position X,Y.
 * Unlike the plans to go near a position, this one assumes that the
 * position is reachable. If the position is not reachable, it will loop forever.
 */

+!pos(X,Y) : pos(X,Y)
   <- .print("I've reached ",X,"x",Y).
+!pos(X,Y) : not pos(X,Y)
   <- !next_step(X,Y);
      !pos(X,Y).



/* Gold-searching Plans */

/* The following plan encodes how an agent should deal with a newly found piece
 * of gold, when it is not carrying gold and it is free.
 * The first step changes the belief so that the agent no longer believes it is free.
 * Then it adds the belief that there is gold in position X,Y, and
 * prints a message. Finally, it calls a plan to handle that piece of gold.
 */

// perceived golds are included as self beliefs (to not be removed once not seen anymore)
+cell(X,Y,gold) <- +gold(X,Y).

@pgold[atomic]           // atomic: so as not to handle another event until handle gold is initialised
+gold(X,Y)
  :  not carrying_gold & free & in_my_region(X)
  <- -free;
     .print("Gold perceived: ",gold(X,Y));
     !init_handle(gold(X,Y)).

// gold outside my region -> hand it to my partner (whose region it is)
@pregion
+gold(X,Y)[source(self)]
  :  partner(P) & not in_my_region(X)
  <- .send(P,tell,gold(X,Y)).

// if I see gold and I'm not free but also not carrying gold yet
// (I'm probably going towards one), abort handle(gold) and pick up
// this one which is nearer
@pcell2[atomic]
+gold(X,Y)
  :  not carrying_gold & not free & in_my_region(X) & team(T) &
     .desire(handle(gold(OldX,OldY))) &   // I desire to handle another gold which
     pos(AgX,AgY) &
     jia.dist(X,   Y,   AgX,AgY,DNewG) &
     jia.dist(OldX,OldY,AgX,AgY,DOldG) &
     DNewG < DOldG                        // is farther than the one just perceived
  <- .drop_desire(handle(gold(OldX,OldY)));
     release(OldX,OldY,T);                // free the abandoned target for my team
     .print("Giving up current gold ",gold(OldX,OldY)," to handle ",gold(X,Y)," which I am seeing!");
     !init_handle(gold(X,Y)).

// my region is overloaded (more known gold than my capacity): ask my partner
// to cross into my region and help with this piece. Only for gold in my own
// region ([source(self)] avoids ping-pong); out-of-region gold is routed by
// @pregion instead.
@pcell3
+gold(X,Y)[source(self)]
  :  in_my_region(X) & not free & partner(P) & capacity(N) & .count(gold(_,_),C) & C > N
  <- .print("Over capacity (",C,">",N,") in my region: asking ",P," to help with ",gold(X,Y));
     .send(P,achieve,help(gold(X,Y))).

// partner asked for help: cross into its region and handle the gold if I'm
// idle (handle itself does not check region); if busy, decline.
+!help(gold(X,Y)) : free
  <- -free;
     .print("Crossing to help my partner with ",gold(X,Y));
     !init_handle(gold(X,Y)).
+!help(gold(X,Y)) : not free
  <- .print("Busy, can't help my partner with ",gold(X,Y)," right now").


/* The next plans encode how to handle a piece of gold.
 * The first one drops the desire to be near some location,
 * which could be true if the agent was just randomly moving around looking for gold.
 * The second one simply calls the goal to handle the gold.
 * The third plan is the one that actually results in dealing with the gold.
 * It raises the goal to go to position X,Y, then the goal to pickup the gold,
 * then to go to the position of the depot, and then to drop the gold and remove
 * the belief that there is gold in the original position.
 * Finally, it prints a message and raises a goal to choose another gold piece.
 * The remaining two plans handle failure.
 */

@pih1[atomic]
+!init_handle(Gold)
  :  .desire(near(_,_))
  <- .print("Dropping near(_,_) desires and intentions to handle ",Gold);
     .drop_desire(near(_,_));
     !init_handle(Gold).
@pih2[atomic]
+!init_handle(Gold)
  :  pos(X,Y)
  <- .print("Going for ",Gold);
     !!handle(Gold). // must use !! to perform "handle" as not atomic

+!handle(gold(X,Y))
  :  not free & team(T)
  <- reserve(X,Y,T,_);   // best-effort: choose_gold already skips reserved gold
     .print("Handling ",gold(X,Y)," now.");
     !pos(X,Y);
     !ensure(pick,gold(X,Y));
     ?depot(_,DX,DY);
     !pos(DX,DY);
     !ensure(drop, 0);
     release(X,Y,T);
     .print("Finish handling ",gold(X,Y));
     ?score(S);
     -+score(S+1);
     .print("(",T,") I have dropped ",S+1," pieces of gold");
     .send(leader,tell,dropped(T));
     !!choose_gold.

// if ensure(pick/drop) failed, release the reservation and pursue another gold
-!handle(gold(X,Y)) : team(T)
  <- release(X,Y,T);
     .print("failed to handle ",gold(X,Y));
     .abolish(gold(X,Y)); // ignore source
     !!choose_gold.

/* The next plans deal with picking up and dropping gold. */

+!ensure(pick,_) : pos(X,Y) & gold(X,Y)
  <- pick;
     ?carrying_gold;
     -gold(X,Y).
// fail if no gold there or not carrying_gold after pick!
// handle(G) will "catch" this failure.

+!ensure(drop, _) : carrying_gold & pos(X,Y) & depot(_,X,Y)
  <- drop.



/* The next plans encode how the agent can choose the next gold piece
 * to pursue (the closest one to its current position) or,
 * if there is no known gold location, makes the agent believe it is free.
 */
+!choose_gold
  :  not gold(_,_)
  <- -+free.

// Finished one gold, but others left
// find the closest gold among the known options,
// Finished one gold, but others left: find the closest one NOT already
// reserved by my own team (partners must not pursue the same target).
+!choose_gold
  :  gold(_,_) & team(T)
  <- .findall(gold(X,Y), gold(X,Y) & not reserved(X,Y,T) & in_my_region(X), LG);
     !calc_gold_distance(LG,LD);
     .length(LD,LLD); LLD > 0;
     .print("Gold distances: ",LD,LLD);
     .min(LD,d(_,NewG));
     .print("Next gold is ",NewG);
     !!handle(NewG).
-!choose_gold <- -+free.

+!calc_gold_distance([],[]).
+!calc_gold_distance([gold(GX,GY)|R],[d(D,gold(GX,GY))|RD])
  :  pos(IX,IY)
  <- jia.dist(IX,IY,GX,GY,D);
     !calc_gold_distance(R,RD).
+!calc_gold_distance([_|R],RD)
  <- !calc_gold_distance(R,RD).


/* Reacting to the winner announced by the leader */

// the leader broadcast that I am the one winning -> brag about it
+winning(A,S)[source(leader)] : .my_name(A)
   <-  -winning(A,S);
       .print("I am the greatest!!!").

// the winner is someone else -> just discard the belief
+winning(A,S)[source(leader)] : true
   <-  -winning(A,S).


/* end of a simulation */

+end_of_simulation(S,_) : true
  <- .drop_all_desires;
     .abolish(gold(_,_));
     .abolish(picked(_));
     -+free;
     .print("-- END ",S," --").
