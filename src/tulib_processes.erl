%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Process-related utility functions.
%%% @copyright 2011 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%
%%%   Copyright 2011-2013 Klarna AB
%%%
%%%   Licensed under the Apache License, Version 2.0 (the "License");
%%%   you may not use this file except in compliance with the License.
%%%   You may obtain a copy of the License at
%%%
%%%       http://www.apache.org/licenses/LICENSE-2.0
%%%
%%%   Unless required by applicable law or agreed to in writing, software
%%%   distributed under the License is distributed on an "AS IS" BASIS,
%%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%   See the License for the specific language governing permissions and
%%%   limitations under the License.
%%%

%%%_* Module declaration ===============================================
-module(tulib_processes).

%%%_* Exports ==========================================================
%% Message passing
-export([ call/2
        , call/3
        , recv/1
        , recv/2
        , send/2
        ]).

%% Utilities
-export([ flush/0
        , flush/1
        , is_up/1
        , kill/1
        , kill/2
        , pid/1
        ]).

%% Synchronization
-export([ sync_with/1
        , syncing_with/2
        , sync_registered/1
        , sync_unregistered/1
        ]).

%% Monitoring
-export([ demonitor/1
        , demonitor/2
        , monitor/1
        , with_monitor/2
        ]).

%% Spawn
-export([ spawn_monitor/1
        , spawn_monitor/3
        , spawn_register/2
        , spawn_register/4
        ]).

-export_type([ m_proc/0
             , prim_proc/0
             , proc/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-record(p,
        { proc     :: prim_proc()
        , monitor  :: reference()
        }).

-opaque m_proc()   :: #p{}.

-type prim_proc()  :: pid()
                    | atom()
                    | {atom(),  node()}.

-type proc()       :: m_proc() | prim_proc().


-define(is_prim_proc(Proc),
        (is_pid(Proc)  orelse
         is_atom(Proc) orelse
        (is_tuple(Proc)            andalso
         size(Proc) =:= 2          andalso
         is_atom(element(1, Proc)) andalso
         is_atom(element(2, Proc))))).

-define(is_proc(Proc), (?is_prim_proc(Proc) orelse is_record(Proc, p))).

%%%_ * send/receive ----------------------------------------------------
-spec call(proc(), _) -> maybe(_, _).
%% @doc Perform a synchronous call to Proc.
call(Proc, Msg) ->
  call(Proc, Msg, timer:seconds(2)).
call(Proc, Msg, Timeout) ->
  tulib_maybe:lift(?thunk(
    ok      = send(Proc, Msg),
    {ok, _} = recv(Proc, Timeout))).

call2_test() ->
  Pid       = spawn(?thunk(receive {Self, foo} -> Self ! {self(), bar} end)),
  {ok, bar} = call(Pid, foo).

call3_test() ->
  Pid        = spawn(?thunk(ok)),
  {error, _} = call(Pid, foo, 1).


-spec send(P::proc(), _) -> ok | {error, no_such_process}.
%% @doc Send P a Msg.
send(#p{proc=Proc}, Msg) ->
  send(Proc, Msg);
send(Proc, Msg0) ->
  {Tag, _, _} = tab(Proc),
  Msg         = {Tag, Msg0},
  case catch Proc ! Msg of
    Msg                   -> ok;
    {'EXIT', {badarg, _}} -> {error, no_such_process}
  end.

-spec recv(P::proc()) -> maybe(_, _).
%% @doc Receive a message from P.
recv(Proc) ->
  recv(Proc, infinity).
recv(#p{proc=Proc, monitor=Monitor}, Timeout) ->
  recv(Proc, Monitor, Timeout);
recv(Proc, Timeout) ->
  {_, From, _} = tab(Proc),
  receive {From, Msg}                    -> {ok, Msg}
  after Timeout                          -> {error, timeout}
  end.
recv(Proc, Monitor, Timeout) ->
  {_, From, Obj} = tab(Proc),
  receive
    {From, Msg}                          -> {ok, Msg};
    {'DOWN', Monitor, process, Obj, Rsn} -> {error, {down, Rsn}}
  after
    Timeout                              -> {error, timeout}
  end.

%%                               Tag     From           Object
tab(Pid)  when is_pid(Pid)   -> {self(), Pid,           Pid};
tab(Name) when is_atom(Name) -> {self(), whereis(Name), {Name, node()}};
tab({Name, Node})            -> {node(), Node,          {Name, Node}}.

send_recv_test() ->
  Self      = self(),

  Pid       = spawn(?thunk({ok, syn} = recv(Self), ok = send(Self, ack))),
  ok        = send(#p{proc=Pid}, syn),
  {ok, ack} = recv(Pid),

  Proc      = ?MODULE:spawn_monitor(?thunk(ok = send(Self, msg))),
  {ok, msg} = recv(Proc),
  ok.

send_recv_error_test() ->
  {error, no_such_process} = send(notregistered, msg),
  {error, {down, normal}}  = recv(?MODULE:spawn_monitor(?thunk(ok))),
  {error, timeout}         = recv(notregistered, 1),
  {error, timeout}         = recv(
                               ?MODULE:spawn_monitor(
                                 ?thunk(receive after infinity -> ok end)), 1),
  ok.

cover_test() ->
  true = {node(), node(), {name, node()}} =:= tab({name, node()}),
  ok.

%%%_ * misc ------------------------------------------------------------
-spec flush() -> ok.
%% @doc Empty the message queue of the calling process.
flush() ->
  receive _ -> flush()
  after   0 -> ok
  end.

-spec flush(_) -> ok.
%% @doc Empty the message queue of the calling process of all Msgs.
flush(Msg) ->
  receive Msg -> flush(Msg)
  after   0   -> ok
  end.

flush_test() ->
  flush(),
  self() ! foo,
  flush(foo),
  receive foo -> foo after 0 -> bar end,
  ok.


-spec is_up(proc()) -> boolean().
%% @doc Return true iff Proc is running.
is_up(Proc) ->
  erlang:demonitor(erlang:monitor(process, pid(Proc)), [info, flush]).

is_up_test() ->
  Pid1  = spawn(?thunk(ok)),
  Pid2  = spawn(?thunk(receive after infinity -> ok end)),
  timer:sleep(10),
  false = is_up(Pid1),
  true  = is_up(Pid2),
  ok.


-spec kill(proc())   -> boolean()
        ; ([proc()]) -> boolean().
%% @doc Kill processes unconditionally.
kill(Proc) ->
  kill(Proc, []).
kill(Proc, Opts) when not is_list(Proc) ->
  kill([Proc], Opts);
kill(Procs, Opts)
  when is_list(Procs)
     , is_list(Opts) ->
  tulib_lists:all([do_kill(pid(P), Opts) || P <- Procs]).

do_kill(undefined, []) ->
  false;
do_kill(Pid, [flush]) ->
  {trap_exit, true} = process_info(self(), trap_exit),
  {links, Pids}     = process_info(self(), links),
  ?hence(lists:member(Pid, Pids)),
  do_kill(Pid, []),
  receive {'EXIT', Pid, killed} -> true end;
do_kill(Pid, [unlink]) ->
  unlink(Pid),
  do_kill(Pid, []);
do_kill(Pid, []) when is_pid(Pid) ->
  erlang:exit(Pid, kill).


kill_test() ->
  process_flag(trap_exit, true),
  F     = ?thunk(receive after infinity -> ok end),
  Pid1  = spawn_link(F),
  true  = kill(Pid1, [flush]),
  Pid2  = spawn_link(F),
  true  = kill(Pid2, [unlink]),
  false = kill(notregistered),
  ok.


-spec pid(P::proc()) -> pid() | undefined.
%% @doc Return P's pid.
pid(#p{proc=P}) ->
  pid(P);
pid(undefined) ->
  undefined;
pid(Pid) when is_pid(Pid) ->
  Pid;
pid(Name) when is_atom(Name) ->
  whereis(Name);
pid({Name, Node}) ->
  case rpc:call(Node, erlang, whereis, [Name]) of
    Pid when is_pid(Pid) -> Pid;
    _                    -> undefined %Mask badrpc
  end.

pid_test() ->
  Self      = self(),
  true      = register(pid_test, Self),
  Proc      = #p{proc=Self},
  Self      = pid(Self),
  Self      = pid(pid_test),
  Self      = pid(Proc),
  undefined = pid(undefined),
  Self      = pid({pid_test, node()}),
  undefined = pid({pid_test, node@host}),
  ok.

%%%_ * sync ------------------------------------------------------------
-define(SYNC, '__sync__').

-spec sync_with(pid()) -> ok | no_return().
%% @doc Sync with Pid, which must call syncing_with/2.
sync_with(Pid) -> receive {Pid, ?SYNC} -> ok end.

-spec syncing_with(pid(), fun(() -> A)) -> maybe(A, _).
%% @doc Execute thunk, then sync with Pid, which must call sync_with/1.
syncing_with(Pid, Thunk) -> tulib_maybe:lift(Thunk, ?thunk(send(Pid, ?SYNC))).

sync_test() ->
  Self = self(),
  sync_with(spawn(?thunk(syncing_with(Self, ?thunk(ok))))),
  ok.


%% @doc Spinlock until Regname has been registered.
sync_registered(Regnames) when is_list(Regnames) ->
  [sync_registered(Regname) || Regname <- Regnames];
sync_registered(Regname) ->
  case lists:member(Regname, registered()) of
    true  -> ok;
    false -> sync_registered(Regname)
  end.

%% @doc Spinlock until Regname has been unregistered.
sync_unregistered(Regnames) when is_list(Regnames) ->
  [sync_unregistered(Regname) || Regname <- Regnames];
sync_unregistered(Regname) ->
  case lists:member(Regname, registered()) of
    true  -> sync_unregistered(Regname);
    false -> ok
  end.

syncreg_test() ->
  Pid = spawn_register(?thunk(receive after infinity -> ok end), regname),
  sync_registered([regname]),
  kill(Pid),
  sync_unregistered([regname]),
  ok.

%%%_ * monitor ---------------------------------------------------------
-spec monitor(prim_proc()) -> m_proc().
%% @doc Add a monitor to Proc.
monitor(Proc) when ?is_prim_proc(Proc) ->
  #p{proc=Proc, monitor=erlang:monitor(process, Proc)}.

-spec demonitor(m_proc()) -> boolean().
%% @doc Attempt to remove a monitor from Proc. Returns true iff
%% successful.
demonitor(Proc)                      -> ?MODULE:demonitor(Proc, [info]).
demonitor(#p{monitor=Monitor}, Opts) -> erlang:demonitor(Monitor, Opts).

demonitor_test() ->
  Proc  = ?MODULE:spawn_monitor(?thunk(receive after infinity -> ok end)),
  true  = ?MODULE:demonitor(Proc),
  false = ?MODULE:demonitor(Proc),
  ok.


-spec with_monitor(prim_proc(), fun()) -> maybe(_, _).
with_monitor(PrimProc, F) ->
  tulib_maybe:lift_with(
    ?MODULE:monitor(PrimProc),
    F,
    fun(Proc) -> ?MODULE:demonitor(Proc, [flush]) end).

with_monitor_test() ->
  {error, {down, _}} = with_monitor(spawn(?thunk(ok)), fun recv/1).

%%%_ * spawn -----------------------------------------------------------
-spec spawn_monitor(fun()) -> #p{}.
spawn_monitor(F) ->
  {Pid, Monitor} = erlang:spawn_monitor(F),
  #p{proc=Pid, monitor=Monitor}.

-spec spawn_monitor(atom(), atom(), [_]) -> #p{}.
spawn_monitor(M, F, A) ->
  {Pid, Monitor} = erlang:spawn_monitor(M, F, A),
  #p{proc=Pid, monitor=Monitor}.

-spec spawn_register(fun(), atom()) -> pid().
spawn_register(F, Name) ->
  proc_lib:spawn(?thunk(register(Name, self()), F())).

-spec spawn_register(atom(), atom(), [_], atom()) -> pid().
spawn_register(M, F, A, Name) ->
  proc_lib:spawn(?thunk(register(Name, self()), apply(M, F, A))).


cover2_test() ->
  ?MODULE:spawn_monitor(tulib_lists, seq, [42]),
  spawn_register(tulib_lists, seq, [42], nym),
  ok.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
