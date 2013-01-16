%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc BETA: Layer 7 proxies.
%%% @copyright 2012 Klarna AB
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
-module(tulib_gen_proxy).
-behaviour(gen_server).

%%%_* Exports ==========================================================
%% gen_proxy behaviour
-export([behaviour_info/1]).

%% API
-export([ add/3
        , forward/2
        , get_current/1
        , get_default/1
        , load/2
        , load/3
        , load/4
        , set_default/2
        , start/1
        , start/2
        , start_link/1
        , start_link/2
        , stop/1
        , unload/2
        ]).

%% gen_server callbacks
-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

-export_type([ header/0
             , name/0
             , parser/0
             , payload/0
             , proxy/0
             , request/0
             , server/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Behaviour -------------------------------------------------------
behaviour_info(callbacks) ->
  [ {add,         2}
  , {forward,     1}
  , {get_current, 0}
  , {get_default, 0}
  , {load,        1}
  , {load,        2}
  , {load,        3}
  , {set_default, 1}
  , {start,       1}
  , {start_link,  1}
  , {stop,        0}
  , {unload,      1}
  ];
behaviour_info(_) -> undefined.

%%%_ * Types -----------------------------------------------------------
-type proxy()            :: pid() | atom().
-type request()          :: _. %\
-type header()           :: _. % } Application specific
-type payload()          :: _. %/
-type parser()           :: fun((request()) -> {header(), payload()}).
-type server()           :: fun((payload()) -> _).
-type routing_table()    :: fun((header()) -> server()).
-type name()             :: atom().

-record(s,
        { parser         :: parser()                     %protocol parser
        , tabs           :: [{name(), routing_table()}]  %known routing tables
        , cur            :: {name(), routing_table()}    %current routing table
        , def            :: {name(), routing_table()}    %default routing table
        , timer          :: reference() | undefined      %current timer
        , count=infinity :: non_neg_integer() | infinity %current countdown
        , reqs=[]        :: [{pid(), _}]                 %current requests
        }).

-define(is_parser(X),        is_function(X, 1)).
-define(is_name(X),          is_atom(X)).
-define(is_routing_table(X), is_function(X, 1)).
-define(is_count(X),         (is_integer(X) andalso X > 0)).

%%%_ * API -------------------------------------------------------------
-spec add(proxy(), name(), routing_table()) -> ok.
%% @doc Add Tab to the router as Name. Overwrites old Name, if any.
add(Proxy, Name, Tab)
  when ?is_name(Name)
     , ?is_routing_table(Tab) ->
  call(Proxy, {add, Name, Tab}).

-spec forward(proxy(), request()) -> _.
%% @doc Forward request as determined by the currently loaded routing
%% table.
forward(Proxy, Req) -> call(Proxy, {forward, Req}).

-spec get_current(proxy()) -> name().
%% @doc Return the name of the current table.
get_current(Proxy) -> call(Proxy, get_current).

-spec get_default(proxy()) -> name().
%% @doc Return the name of the default table.
get_default(Proxy) -> call(Proxy, get_default).

-spec set_default(proxy(), name()) -> maybe(_, _).
%% @doc Set Name as the default table iff the router knows about it.
set_default(Proxy, Name) when ?is_name(Name) ->
  call(Proxy, {set_default, Name}).

-spec load(proxy(), name()) -> maybe(_, _).
%% @doc Load table Name.
load(Proxy, Name) when ?is_name(Name) ->
  call(Proxy, {load, Name, infinity, infinity}).

-spec load(proxy(), name(), non_neg_integer()) -> maybe(_, _).
%% @doc Load table Name for the next N requests (then revert to default
%% table).
load(Proxy, Name, N)
  when ?is_name(Name)
     , ?is_count(N) ->
  call(Proxy, {load, Name, N, infinity}).

-spec load(proxy(), name(), non_neg_integer() | infinity, timeout()) ->
              maybe(_, _).
%% @doc Load Name for the next N requests, or T milliseconds
%% (then revert to default table).
load(Proxy, Name, N, T)
  when ?is_name(Name)
     , (?is_count(N) orelse N =:= infinity)
     , ?is_count(T) ->
 call(Proxy, {load, Name, N, T}).

-spec unload(proxy(), name()) -> maybe(_, _).
%% @doc Revert to default table iff Name is currently loaded.
unload(Proxy, Name) -> call(Proxy, {unload, Name}).


-spec start(_) -> pid().
start(Args) ->
  gen_server:start(?MODULE, Args, []).

-spec start(atom(), _) -> atom().
start(Name, Args) when is_atom(Name) ->
  gen_server:start({local, Name}, ?MODULE, Args, []).

-spec start_link(_) -> pid().
start_link(Args) ->
  gen_server:start_link(?MODULE, Args, []).

-spec start_link(atom(), _) -> atom().
start_link(Name, Args) when is_atom(Name) ->
  gen_server:start_link({local, Name}, ?MODULE, Args, []).


-spec stop(proxy()) -> ok.
stop(Proxy)         -> call(Proxy, stop).


call(Proxy, Req) -> gen_server:call(Proxy, Req).

%%%_ * gen_server callbacks --------------------------------------------
init(Args) ->
  process_flag(trap_exit, true),
  {ok, P}  = tulib_lists:assoc(parser,       Args),
  {ok, Ts} = tulib_lists:assoc(tabs,         Args),
  {ok, N}  = tulib_lists:assoc(default_name, Args),
  {ok, D}  = tulib_lists:assoc(N, Ts),
  ?hence(?is_parser(P)),
  [?hence(?is_name(Name) andalso ?is_routing_table(Tab)) || {Name, Tab} <- Ts],
  {ok, #s{ parser = P
         , tabs   = Ts
         , cur    = {N, D}
         , def    = {N, D}
         }}.

terminate(_, #s{}) -> ok.

code_change(_, S, _) -> {ok, S}.

handle_call({forward, Req}, From, #s{ parser = P
                                    , cur    = {_, C} = Cur
                                    , def    = {_, D} = Def
                                    , count  = N
                                    , reqs   = Reqs
                                    }        = S) ->
  Pid = request(Req, From, P, C, D),
  {noreply, S#s{ cur   = case dec(N) of 0 -> Def; _ -> Cur end
               , count = dec(N)
               , reqs  = [{Pid, From}|Reqs]
               }};
handle_call({add, Name, Tab}, _, #s{tabs=Tabs} = S) ->
  {reply, ok, S#s{tabs=[{Name, Tab}|Tabs]}};
handle_call(get_current, _, #s{cur={N, _}} = S) ->
  {reply, N, S};
handle_call(get_default, _, #s{def={N, _}} = S) ->
  {reply, N, S};
handle_call({set_default, Name}, _, #s{tabs=Tabs} = S) ->
  case tulib_lists:assoc(Name, Tabs) of
    {ok, Tab}         -> {reply, ok, S#s{def={Name, Tab}}};
    {error, notfound} -> {reply, {error, no_such_table}, S}
  end;
handle_call({load, Name, N, T}, _, #s{tabs=Tabs} = S) ->
  case tulib_lists:assoc(Name, Tabs) of
    {ok, Tab} -> {reply, ok, S#s{cur={Name, Tab}, count=N, timer=timer(T)}};
    {error, notfound} -> {reply, {error, no_such_table}, S}
  end;
handle_call({unload, Name}, _, #s{cur={N, _}, def=D} = S) ->
  case Name =:= N of
    true  -> {reply, ok, S#s{cur=D}};
    false -> {reply, {error, {Name, '=/=', N}}, S}
  end;
handle_call(stop, _, S) ->
  {stop, normal, ok, S}.

handle_cast(_Msg, S) -> {stop, bad_cast, S}.

handle_info({Ref, timeout}, #s{def=D, timer=Ref} = S) ->
  {noreply, S#s{cur=D, timer=undefined}};
handle_info({_, timeout}, S) ->
  {noreply, S};
handle_info({'EXIT', Pid, Rsn}, #s{reqs=Reqs} = S) ->
  {ok, From} = tulib_lists:assoc(Pid, Reqs),
  [begin
     ?error("EXIT ~p: ~p", [Pid, Rsn]),
     gen_server:reply(From, {error, Rsn})
   end || Rsn =/= normal],
  {noreply, S#s{reqs=tulib_lists:assoc_delete(Pid, Reqs)}};
handle_info(Msg, S) ->
  ?warning("~p", [Msg]),
  {noreply, S}.

%%%_ * Internals -------------------------------------------------------
dec(N) when ?is_count(N) -> N - 1;
dec(0)                   -> 0;
dec(infinity)            -> infinity.

timer(T) when ?is_count(T) ->
  Ref     = make_ref(),
  {ok, _} = timer:send_after(T, self(), {Ref, timeout}),
  Ref;
timer(infinity) -> undefined.


request(Req, From, Parser, Current, Default) ->
  proc_lib:spawn_link(?thunk(
    {Header, Payload} = Parser(Req),
    gen_server:reply(From,
      case ?lift(Current(Header)) of
        {ok, Server} -> Server(Payload);
        {error, _}   -> (Default(Header))(Payload)
      end))).

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  Custom                          = fun(h1) -> fun tulib_combinators:i/1;
                                       (h2) -> tulib_combinators:k(ok)
                                    end,
  {ok, Proxy}                     = start(args()),

  foo                             = forward(Proxy, {header,foo}),

  ok                              = add(Proxy, custom, Custom),
  default                         = get_default(Proxy),
  default                         = get_current(Proxy),
  {error, no_such_table}          = set_default(Proxy, defaul),
  ok                              = set_default(Proxy, default),

  {error, no_such_table}          = load(Proxy, custo),
  ok                              = load(Proxy, custom),
  custom                          = get_current(Proxy),
  foo                             = forward(Proxy, {h1,foo}),
  ok                              = forward(Proxy, {h2,foo}),

  {error, {custo, '=/=', custom}} = unload(Proxy, custo),
  ok                              = unload(Proxy, custom),
  foo                             = forward(Proxy, {h2,foo}),

  ok                              = load(Proxy, custom, 2),
  ok                              = forward(Proxy, {h2,foo}),
  ok                              = forward(Proxy, {h2,foo}),
  foo                             = forward(Proxy, {h2,foo}),

  ok                              = load(Proxy, custom, infinity, 10),
  ok                              = forward(Proxy, {h2,foo}),
  ok                              = timer:sleep(11),
  foo                             = forward(Proxy, {h2,foo}),

  ok                              = stop(Proxy),
  ok.

args() ->
  [ {parser,       fun tulib_combinators:i/1}
  , {tabs,         [{default, tulib_combinators:k(fun tulib_combinators:i/1)}]}
  , {default_name, default}
  ].

cover_test() ->
  behaviour_info(callbacks),
  behaviour_info(foo),
  {ok, _} = start(proxy1, args()),
  {ok, _} = start_link(args()),
  {ok, _} = start_link(proxy2, args()),
  {ok, bar} = code_change(foo, bar, baz),
  gen_server:cast(proxy1, msg),
  proxy2 ! msg,
  timer:sleep(100),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
