%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc BETA: Write-through ETS caches.
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
-module(tulib_gen_cache).
-behaviour(gen_server).

%%%_* Exports ==========================================================
%% gen_cache behaviour
-export([behaviour_info/1]).

%% API
-export([ insert/4
        , invalidate/3
        , lookup/3
        , start/1
        , start/2
        , start_link/1
        , start_link/2
        , stop/1
        ]).

%% gen_server callbacks
-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

%% Internal exports
-export([ cache/1
        ]).

-export_type([ cache/0
             , key/0
             , tab/0
             , val/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/logging.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Behaviour -------------------------------------------------------
behaviour_info(callbacks) ->
  [ {hit,        2} %\
  , {init,       1} % \
  , {invalid,    2} %  } Caching policy
  , {miss,       2} % /
  , {replace,    2} %/
  , {fetch,      2} %\ Backing
  , {store,      3} %/ store
  , {insert,     3} %\
  , {invalidate, 2} % \
  , {lookup,     2} %  \ Specific
  , {start,      0} %  / server
  , {start_link, 0} % /
  , {stop,       0} %/
  ];
behaviour_info(_) -> undefined.

%%%_ * Types -----------------------------------------------------------
-type cache()               :: atom() | pid().
-type tab()                 :: _.
-type key()                 :: _.
-type val()                 :: _.

-record(s,
        { cb                :: atom()                  %Callback module
        , caches=dict:new() :: dict:dict(tab(), pid()) %name -> ETS tab owner
        , sehcac=dict:new() :: dict:dict(pid(), tab()) %reverse mapping (GC)
        }).

%%%_ * API -------------------------------------------------------------
-spec insert(cache(), tab(), key(), val()) -> whynot().
%% @doc Write Val to backing store and update cache if needed.
insert(Cache, Tab, Key, Val) -> call(Cache, {insert, Tab, Key, Val}).

-spec invalidate(cache(), tab(), key()) -> whynot().
%% @doc Inform Cache about {Tab, Key}'s invalidity.
invalidate(Cache, Tab, Key) -> call(Cache, {invalidate, Tab, Key}).

-spec lookup(cache(), tab(), key()) -> maybe(_, notfound).
%% @doc Return the cached value for {Tab, Key} or read it from backing
%% store.
lookup(Cache, Tab, Key) -> call(Cache, {lookup, Tab, Key}).


start(A)       -> gen_server:start(?MODULE, A, []).
start(Name, A) -> gen_server:start({local, Name}, ?MODULE, A, []).

start_link(A)       -> gen_server:start_link(?MODULE, A, []).
start_link(Name, A) -> gen_server:start_link({local, Name}, ?MODULE, A, []).

stop(Cache) -> call(Cache, stop).


call(Cache, Req) -> gen_server:call(Cache, Req).

%%%_ * gen_server callbacks --------------------------------------------
init(Args) ->
  process_flag(trap_exit, true),
  {ok, Cb} = tulib_lists:assoc(cb, Args),
  {ok, #s{cb=Cb}}.

terminate(_, #s{caches=Cs}) ->
  [ok = cache_stop(Cache) || {_, Cache} <- dict:to_list(Cs)],
  ok.

code_change(_, S, _) -> {ok, S}.

handle_call({insert, Tab, Key, Val}, From, S) ->
  Cache = get(S, Tab),
  ok    = cache_insert(Cache, Key, Val, From),
  {noreply, put(S, Tab, Cache)};
handle_call({invalidate, Tab, Key}, From, S) ->
  Cache = get(S, Tab),
  ok    = cache_invalidate(Cache, Key, From),
  {noreply, put(S, Tab, Cache)};
handle_call({lookup, Tab, Key}, From, S) ->
  Cache = get(S, Tab),
  ok    = cache_lookup(Cache, Key, From),
  {noreply, put(S, Tab, Cache)};
handle_call(stop, _, S) ->
  {stop, normal, ok, S}.

handle_cast(_Msg, S) -> {stop, bad_cast, S}.

handle_info({'EXIT', Pid, Rsn}, S) ->
  ?error("EXIT ~p: ~p", [Pid, Rsn]),
  {noreply, del(S, Pid)};
handle_info(Msg, S) ->
  ?warning("~p", [Msg]),
  {noreply, S}.


get(#s{cb=Cb, caches=Cs}, Tab) ->
    case dict:find(Tab, Cs) of
      {ok, C} -> C;
      error   -> cache_new(Tab, Cb)
    end.

put(#s{caches=Cs, sehcac=Ss} = S, Tab, Cache) ->
  S#s{ caches = dict:store(Tab, Cache, Cs)
     , sehcac = dict:store(Cache, Tab, Ss)
     }.

del(#s{caches=Cs, sehcac=Ss} = S, Pid) ->
   S#s{ caches = dict:erase(dict:fetch(Pid, Ss), Cs)
      , sehcac = dict:erase(Pid,                 Ss)
      }.

%%%_ * Caches ----------------------------------------------------------
-record(cache,
        { tab    :: tab()
        , cb     :: atom()
        , parent :: pid()
        , ets    :: _
        , state  :: _
        }).

cache_new(Tab, Cb) ->
  Self = self(),
  proc_lib:spawn_link(?thunk(
    Ets   = ets:new(tulib_atoms:catenate(['gen_cache_', Tab]), [private]),
    State = Cb:init(Ets),
    cache(#cache{tab=Tab, cb=Cb, parent=Self, ets=Ets, state=State}))).

cache_stop(C)                -> tulib_processes:send(C, stop).
cache_insert(C, K, V, From)  -> tulib_processes:send(C, {insert, K, V, From}).
cache_invalidate(C, K, From) -> tulib_processes:send(C, {invalidate, K, From}).
cache_lookup(C, K, From)     -> tulib_processes:send(C, {lookup, K, From}).

cache(#cache{parent=P} = C) ->
  receive
    {P, {insert, Key, Val, From}} -> ?MODULE:cache(do_insert(Key,Val,From,C));
    {P, {invalidate, Key, From}}  -> ?MODULE:cache(do_invalidate(Key,From,C));
    {P, {lookup, Key, From}}      -> ?MODULE:cache(do_lookup(Key,From,C));
    {P, stop}                     -> ok
  end.


do_insert(Key, Val, From, #cache{tab=Tab, cb=Cb, ets=Ets} = C) ->
  case Cb:store(Tab, Key, Val) of
    ok ->
      gen_server:reply(From, ok),
      %% New values are introduced into the cache in do_lookup/3.
      ets:lookup(Ets, Key) =/= [] andalso (true = ets:insert(Ets, {Key, Val}));
    {error, _} = Err -> gen_server:reply(From, Err)
  end,
  C.

do_invalidate(Key, From, #cache{cb=Cb, ets=Ets, state=State} = C) ->
  true = ets:delete(Ets, Key),
  gen_server:reply(From, ok),
  C#cache{state=Cb:invalid(State, Key)}.

do_lookup(Key, From, #cache{tab=Tab, cb=Cb, ets=Ets, state=State0} = C) ->
  case ets:lookup(Ets, Key) of
    [{Key, Val}] ->
      State = Cb:hit(State0, Key),
      gen_server:reply(From, {ok, Val}),
      C#cache{state=State};
    [] ->
      State1 = Cb:miss(State0, Key),
      case Cb:fetch(Tab, Key) of
        {ok, Val} = Ok ->
          gen_server:reply(From, Ok),
          {State, Evict} = Cb:replace(State1, Key),
          [true = ets:delete(Ets, K) || K <- Evict],
          true = ets:insert(Ets, {Key, Val}),
          C#cache{state=State};
        {error, notfound} = Err ->
          gen_server:reply(From, Err),
          C#cache{state=State1}
      end

  end.

%%%_* Tests ============================================================
-ifdef(TEST).

basic_test() ->
  {ok, Cache} = start(args()),

  ok          = insert(Cache, tab, key, foo),
  {ok, foo}   = lookup(Cache, tab, key),
  {ok, foo}   = lookup(Cache, tab, key),
  ok          = invalidate(Cache, tab, key),
  {ok, foo}   = lookup(Cache, tab, key),

  ok          = stop(Cache),
  ok.

args() -> [{cb, test_cache}].

cover_test() ->
  behaviour_info(callbacks),
  behaviour_info(foo),
  {ok, _} = start(cache1, args()),
  {ok, _} = start_link(args()),
  {ok, _} = start_link(cache2, args()),
  {ok, bar} = code_change(foo, bar, baz),
  gen_server:cast(cache1, msg),
  cache2 ! msg,
  timer:sleep(100),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
