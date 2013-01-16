%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc BETA: Simplified interface to gen_tcp.
%%% @todo test large messages
%%% @todo test error cases
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
-module(tulib_sockets).

%%%_* Exports ==========================================================
-export([ accept/1
        , box/2
        , close/1
        , connect/1
        , connect/2
        , listen/1
        , recv/1
        , recv/2
        , send/2
        , with_socket/2
        , with_socket/3
        ]).

-export_type([ box/0
             , lsock/0
             , sock/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/guards.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Private constructors --------------------------------------------
-record(lso, {ck::_}).
-opaque lsock() :: #lso{}.

-record(so, {ck::_}).
-opaque sock() :: #so{}.

lsock(ListeningSocket) ->
  tulib_maybe:lift_with(ListeningSocket,
                        fun(ListeningSocket) -> #lso{ck=ListeningSocket} end).

sock(GenTcpSocket) ->
  tulib_maybe:lift_with(GenTcpSocket,
                        fun(GenTcpSocket) -> #so{ck=GenTcpSocket} end).

%%%_ * ADT -------------------------------------------------------------
-record(box,
        { ip
        , port
        }).

-opaque box() :: #box{}.

box(IP, Port) -> #box{ip=IP, port=Port}.

%%%_ * Open/close ------------------------------------------------------
-spec listen(box())                   -> maybe(lsock(), _)
          ; (inet:ip_port())          -> maybe(lsock(), _).
%% @doc Listen for TCP/IP connection attempts on Port.
listen(#box{ip=undefined, port=Port}) -> listen(Port, []);
listen(#box{ip=IP, port=Port})        -> listen(Port, [{ip, IP}]);
listen(Port) when ?is_ip_port(Port)   -> listen(Port, []).
listen(Port, Opts)                    -> lsock(gen_tcp:listen(Port,
                                                              opts(Opts))).


-spec connect(box()) -> maybe(sock(), _).
%% @doc Connect to IP/Port.
connect(#box{} = Box) ->
  connect(Box, []).
connect(#box{ip=IP, port=Port}, Opts) ->
  connect(IP, Port, Opts).
connect(IP, Port, Opts) ->
  sock(gen_tcp:connect(IP, Port, opts(Opts))).


-spec accept(lsock())  -> maybe(sock(), _).
%% @doc Accept a connection on Lsock.
accept(#lso{ck=Lsock}) -> sock(gen_tcp:accept(Lsock)).


-spec close(sock()) -> maybe(_, _).
%% @doc Close the connection on Sock.
close(#so{ck=Sock}) -> flush(Sock), gen_tcp:close(Sock).

flush(Sock) ->
  receive
    {tcp, Sock, _}       -> flush(Sock);
    {tcp_closed, Sock}   -> flush(Sock);
    {tcp_error, Sock, _} -> flush(Sock)
  after
    0 -> ok
  end.

opts([{ip, _IP} = Opt]) ->
  [Opt|opts([])];
opts([]) ->
   [ inet
   , binary
   , {packet, raw}
   , {active, once}
   ].


-spec with_socket(box() | sock(), fun((sock()) -> A)) -> maybe(A, _).
%% @doc Apply F to a socket connected to Box.
with_socket(#box{} = Box, F) ->
  with_socket(Box, [], F);
with_socket(#so{} = Sock, F) ->
  tulib_maybe:lift_with(Sock, F, fun close/1).
with_socket(#box{} = Box, Opts, F) ->
  tulib_maybe:lift_with(connect(Box, Opts),
                        fun(Sock) -> with_socket(Sock, F) end).

%%%_ * Send/receive ----------------------------------------------------
-spec recv(sock()) -> maybe(_, _).
%% Receive an Erlang term via TCP/IP.
recv(Sock) ->
  recv(Sock, infinity).
recv(#so{ck=Sock}, Timeout) ->
  receive
    {tcp, Sock, Bin}       -> inet:setopts(Sock, [{active, once}]), b2t(Bin);
    {tcp_closed, Sock}     -> {error, closed};
    {tcp_error, Sock, Rsn} -> {error, Rsn}
  after
    Timeout                -> {error, timeout}
  end.

%% Safe binary->term conversion.
b2t(Bin) ->
  case catch ?b2t(Bin) of
    {'EXIT', _} -> {error, badbin};
    Term        -> {ok, Term}
  end.

-spec send(sock(), _) -> whynot().
%% Send an Erlang term via TCP/IP.
send(#so{ck=Sock}, Term) -> gen_tcp:send(Sock, ?t2b(Term)).

%%%_* Tests ============================================================
-ifdef(TEST).
-ifdef(NOJENKINS).

sock_test() ->
  Self = self(),
  %% Server
  Pid  =
    spawn(?thunk(
      {ok, Lsock} = listen(#box{port=0}),
      {ok, Port}  = inet:port(Lsock#lso.ck),
      Self ! {self(), Port},
      {ok, Sock}  = accept(Lsock),
      {ok, foo}   = recv(Sock),
      ok          = send(Sock, bar),
      ok          = close(Sock))),
  %% Client
  Port    = receive {Pid, N} -> N end,
  {ok, _} = with_socket(box(localhost, Port), fun(Sock) ->
    ok         = send(Sock, foo),
    {ok, bar}  = recv(Sock)
  end).

-endif.
-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
