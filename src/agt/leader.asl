// leader agent

{ include("$jacamoJar/templates/common-cartago.asl") }

/*
 * By Joao Leite
 * Based on implementation developed by Rafael Bordini, Jomi Hubner and Maicon Zatelli
 */


score(miner1,0).
score(miner2,0).
score(miner3,0).
score(miner4,0).

winning(none,0). // who is currently winning and with how many gold pieces

//the start goal only works after execise j)
//!start.
//+!start <- tweet("a new mining is starting! (posted by jason agent)").

+dropped(Team)[source(A)] : score(A,S) & winning(L,SL) & S+1 > SL
   <- -score(A,S);
      +score(A,S+1);
      -dropped(Team)[source(A)];
      -+winning(A,S+1);
      .print("Agent ",A," from ",Team," is winning with ",S+1," pieces of gold");
      .broadcast(tell,winning(A,S+1)).

+dropped(Team)[source(A)] : score(A,S)
   <- -score(A,S);
      +score(A,S+1);
      -dropped(Team)[source(A)];
      .print("Agent ",A," from ",Team," has dropped ",S+1," pieces of gold").
