-module(neptune_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).

groups() ->
    [{build_in_src_tree,
      [bootstrap,
       configure_in,
       all_in,
       maintainer_clean]},
     {build_out_of_src_tree,
      [bootstrap,
       configure_out,
       all_out,
       mostlyclean]}].

all() ->
    [neptune,
     {group, build_in_src_tree},
     {group, build_out_of_src_tree}].

init_per_suite(Config) ->
    Env = env(Config),
    ok = ct:pal("~p", [Env]),
    file:del_dir_r("/tmp/myapp"),
    file:del_dir_r("/tmp/build"),
    [{env, Env}, {tmpdir, "/tmp"} | Config].

end_per_suite(_Config) ->
    file:del_dir_r("/tmp/myapp"),
    file:del_dir_r("/tmp/build").

env(_Config) ->
    TopBuildDir = ct:get_config(top_builddir),
    Env = os:env(),
    {"PATH", Path} = lists:keyfind("PATH", 1, Env),
    case re:run(Path, "neptune") of
	{match, _} ->
	    Env;
	nomatch ->
	    NewPath = filename:join(TopBuildDir, bin) ++ [$: | Path],
	    lists:keyreplace("PATH", 1, Env, {"PATH", NewPath})
    end.

neptune(Config) ->
    Env = ?config(env, Config),
    Dir = ?config(tmpdir, Config),
    Port = open_port(
	     {spawn, "neptune --outdir /tmp myapp"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

bootstrap(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), myapp),
    Port = open_port(
	     {spawn, "./bootstrap.sh"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

configure_in(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), myapp),
    Port = open_port(
	     {spawn, "./configure"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

all_in(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), myapp),
    Port = open_port(
	     {spawn, "make"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

maintainer_clean(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), myapp),
    Port = open_port(
	     {spawn, "make maintainer-clean"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

configure_out(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), build),
    ok = file:make_dir(Dir),
    Port = open_port(
	     {spawn, "../myapp/configure"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

all_out(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), build),
    Port = open_port(
	     {spawn, "make"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

mostlyclean(Config) ->
    Env = ?config(env, Config),
    Dir = filename:join(?config(tmpdir, Config), build),
    Port = open_port(
	     {spawn, "make mostlyclean"},
	     port_opts(Dir, Env)),
    ok = get_response(Port, []).

port_opts(Dir, Env) ->
    [{cd, Dir},
     {env, Env},
     stderr_to_stdout,
     exit_status].

get_response(Port, Acc) ->
    receive
	{Port, {data, Data}} ->
	    get_response(Port, [Data | Acc]);
	{Port, {exit_status, 0}}->
	    ok = pal(Acc);
	{Port, {exit_status, ExitStatus}}->
	    ok = pal(Acc),
	    {error, ExitStatus}
    end.

pal(Acc) ->
    ct:pal("~s", [lists:reverse(Acc)]).
