%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Predicates for use in guards.
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

-ifndef(__GUARDS_HRL).
-define(__GUARDS_HRL, true).

-define(is_ip_address(IP),
        (is_tuple(IP)
         andalso (size(IP) =:= 4)
         andalso (0 =< element(1, IP) andalso element(1, IP) =< 255)
         andalso (0 =< element(2, IP) andalso element(2, IP) =< 255)
         andalso (0 =< element(3, IP) andalso element(3, IP) =< 255)
         andalso (0 =< element(4, IP) andalso element(4, IP) =< 255))).

-define(is_ip_port(Port),
        (is_integer(Port) andalso (0 =< Port andalso Port =< 65535))).

-define(is_string(Str),
        (Str =:= "" orelse (is_list(Str) andalso is_integer(hd(Str))))).

-define(is_thunk(Thunk), is_function(Thunk, 0)).

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
