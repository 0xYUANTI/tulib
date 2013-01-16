%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc String utilities.
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
-module(tulib_strings).

%%%_* Exports ==========================================================
-export([ fmt/2
        , to_lower_latin1/1
        , to_upper_latin1/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
-spec fmt(string(), [_]) -> string().
%% @doc Fill Format with Args and return the result as a string.
fmt(Format, Args)        -> lists:flatten(io_lib:format(Format, Args)).

fmt_test()               -> "foo bar" = fmt("foo ~s", ["bar"]).


%% @doc Modified http_util:to_lower version to handle the full
%% range of latin-1. Based on info at:
%% http://www.htmlhelp.com/reference/charset/
%% Handles both 7bit ASCII and Latin-1 (ISO 8895-1).
%% Unlike string:to_lower will not crash on characters outside Latin-1.
-spec to_lower_latin1((string()|integer())) -> (string()|integer()).
to_lower_latin1(Str) when is_list(Str) ->
  [to_lower_latin1(C) || C <- Str];
to_lower_latin1(C) when C >= $A, C =< $Z ->
  C + ($a - $A);
%% 192 = A grave, 214 = O umlaut
%% 224 = a grave
to_lower_latin1(C) when C >= 192, C =< 214 ->
  C + (224 - 192);
%% 216 = O slash, 222 = THORN
%% 248 = o slash
to_lower_latin1(C) when C >= 216, C =< 222 ->
  C + (248 - 216);
to_lower_latin1(C) ->
  C.

%% @doc Modified http_util:to_upper version to handle the full
%% range of latin-1. Based on info at:
%% http://www.htmlhelp.com/reference/charset/
%% Handles both 7bit ASCII and Latin-1 (ISO 8895-1).
%% Unlike string:to_lower will not crash on characters outside Latin-1.
-spec to_upper_latin1((string()|integer())) -> (string()|integer()).
to_upper_latin1(Str) when is_list(Str) ->
  [to_upper_latin1(C) || C <- Str];
to_upper_latin1(C) when C >= $a, C =< $z ->
  C - ($a - $A);
%% 224 = a grave, 246 = o umlaut
%% 192 = A grave
to_upper_latin1(C) when C >= 224, C =< 246 ->
  C - (224 - 192);
%% 248 = o slash, 254 = thorn
%% 216 = O slash
to_upper_latin1(C) when C >= 248, C =< 254 ->
  C - (248 - 216);
to_upper_latin1(C) ->
  C.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
