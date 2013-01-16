%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc ALPHA: Password hashing.
%%% Requires https://github.com/smarkets/erlang-bcrypt
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
-module(tulib_pw).

%%%_* Exports ==========================================================
-export([ hash/1
        , verify/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
-spec hash(string()) -> string().
%% @doc Hash PW.
hash(_PW) -> throw(nyi).
  %% {ok, Salt} = bcrypt:gen_salt(),
  %% {ok, Hash} = bcrypt:hashpw(PW, Salt),
  %% Hash.

-spec verify(string(), string()) -> boolean().
%% @doc Return true iff PW hashes to Hash.
verify(_PW, _Hash) -> throw(nyi).
%%{ok, Hash} =:= bcrypt:hashpw(PW, Hash).

%% hash_verify_test() ->
%%     Hash  = hash("foo"),
%%     true  = verify("foo", Hash),
%%     false = verify("bar", Hash),
%%     ok.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
