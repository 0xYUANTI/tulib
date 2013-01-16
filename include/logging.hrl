%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Logging-related convenience macros.
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

-ifndef(__LOGGING_HRL).
-define(__LOGGING_HRL, true).

-ifdef(TULIB_USE_LAGER).

-define(debug(Format, Args),     lager:debug(Format, Args)).
-define(info(Format, Args),      lager:info(Format, Args)).
-define(notice(Format, Args),    lager:notice(Format, Args)).
-define(warning(Format, Args),   lager:warning(Format, Args)).
-define(error(Format, Args),     lager:error(Format, Args)).
-define(critical(Format, Args),  lager:critical(Format, Args)).
-define(alert(Format, Args),     lager:alert(Format, Args)).
-define(emergency(Format, Args), lager:emergency(Format, Args)).

-else.

-ifdef(TULIB_DEBUG).
-define(debug(Msg),              ?debug(Msg, [])).
-define(debug(Format, Args),     ?do_debug("~p:~s:~p: Debug: " Format "~n",
                                          [self(), ?FILE, ?LINE|Args])).
-else.
-define(debug(Msg),              ok).
-define(debug(Format, Args),     ok).
-endif. %TULIB_DEBUG

-define(info(Msg),               ?info(Msg, [])).
-define(info(Format, Args),      ?do_info("~p:~s:~p: Info: " Format "~n",
                                          [self(), ?FILE, ?LINE|Args])).
-define(notice(Msg),             ?notice(Msg, [])).
-define(notice(Format, Args),    ?do_notice("~p:~s:~p: Notice: " Format "~n",
                                            [self(), ?FILE, ?LINE|Args])).
-define(warning(Msg),            ?warning(Msg, [])).
-define(warning(Format, Args),   ?do_warning("~p:~s:~p: Warning: " Format "~n",
                                             [self(), ?FILE, ?LINE|Args])).
-define(error(Msg),              ?error(Msg, [])).
-define(error(Format, Args),     ?do_error("~p:~s:~p: Error: " Format "~n",
                                           [self(), ?FILE, ?LINE|Args])).
-define(critical(Msg),           ?critical(Msg, [])).
-define(critical(Format, Args),  ?do_critical("~p:~s:~p: Critical: " Format "~n",
                                              [self(), ?FILE, ?LINE|Args])).
-define(alert(Msg),              ?alert(Msg, [])).
-define(alert(Format, Args),     ?do_alert("~p:~s:~p: Alert: " Format "~n",
                                           [self(), ?FILE, ?LINE|Args])).
-define(emergency(Msg),          ?emergency(Msg, [])).
-define(emergency(Format, Args), ?do_emergency("~p:~s:~p: Emergency: " Format "~n",
                                               [self(), ?FILE, ?LINE|Args])).

-ifdef(TULIB_USE_KLOG).

-define(do_debug(Format, Args),     klog:format(tulib, Format, Args)).
-define(do_info(Format, Args),      klog:format(tulib, Format, Args)).
-define(do_notice(Format, Args),    klog:format(tulib, Format, Args)).
-define(do_warning(Format, Args),   klog:format(tulib, Format, Args)).
-define(do_error(Format, Args),     klog:format(tulib, Format, Args)).
-define(do_critical(Format, Args),  klog:format(tulib, Format, Args)).
-define(do_alert(Format, Args),     klog:format(tulib, Format, Args)).
-define(do_emergency(Format, Args), klog:format(tulib, Format, Args)).

-else.
-ifdef(TULIB_USE_NOLOG).

-define(do_debug(Format, Args),     ok).
-define(do_info(Format, Args),      ok).
-define(do_notice(Format, Args),    ok).
-define(do_warning(Format, Args),   ok).
-define(do_error(Format, Args),     ok).
-define(do_critical(Format, Args),  ok).
-define(do_alert(Format, Args),     ok).
-define(do_emergency(Format, Args), ok).

-else.

%% Default
-define(do_debug(Format, Args),     error_logger:info_msg(Format, Args)).
-define(do_info(Format, Args),      error_logger:info_msg(Format, Args)).
-define(do_notice(Format, Args),    error_logger:info_msg(Format, Args)).
-define(do_warning(Format, Args),   error_logger:warning_msg(Format, Args)).
-define(do_error(Format, Args),     error_logger:warning_msg(Format, Args)).
-define(do_critical(Format, Args),  error_logger:error_msg(Format, Args)).
-define(do_alert(Format, Args),     error_logger:error_msg(Format, Args)).
-define(do_emergency(Format, Args), error_logger:error_msg(Format, Args)).

-endif. %TULIB_USE_NOLOG

-endif. %TULIB_USE_KLOG

-endif. %TULIB_USE_LAGER

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
