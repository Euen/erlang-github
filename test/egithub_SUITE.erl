-module(egithub_SUITE).

-export([
         all/0,
         init_per_suite/1,
         end_per_suite/1
        ]).

-export([
         pull_reqs/1,
         issue_comments/1,
         issues/1,
         files/1,
         users/1,
         orgs/1,
         repos/1,
         teams/1,
         hooks/1,
         collaborators/1,
         statuses/1
        ]).

-record(client, {}).

-define(EXCLUDED_FUNS,
        [
         module_info,
         all,
         test,
         init_per_suite,
         end_per_suite
        ]).

-type config() :: [{atom(), term()}].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Common test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec all() -> [atom()].
all() ->
  Exports = ?MODULE:module_info(exports),
  [F || {F, _} <- Exports, not lists:member(F, ?EXCLUDED_FUNS)].

-spec init_per_suite(config()) -> config().
init_per_suite(Config) ->
  {ok, _} = egithub:start(),
  Config.

-spec end_per_suite(config()) -> config().
end_per_suite(Config) ->
  ok = application:stop(egithub),
  Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Test cases
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pull_reqs(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    PRFilesFun = match_fun("/repos/user/repo/pulls/1/files", get),
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    meck:expect(hackney, send_request, PRFilesFun),
    {ok, _} = egithub:pull_req_files(Credentials, "user/repo", 1),

    PRCommentLineFun = match_fun("/repos/user/repo/pulls/1/comments", post),
    meck:expect(hackney, send_request, PRCommentLineFun),
    {ok, _} = egithub:pull_req_comment_line(Credentials, "user/repo", 1,
                                            "SHA", <<"file-path">>,
                                            5, "comment text"),

    Self = self(),
    PRCommentLineQueueFun = fun(_, {_, _, _, _}) ->
                                Self ! ok,
                                {ok, 200, [], #client{}}
                            end,
    meck:expect(hackney, send_request, PRCommentLineQueueFun),
    ok = egithub:pull_req_comment_line(Credentials, "user/repo", 1,
                                       "SHA", <<"file-path">>,
                                       5, "comment text",
                                       #{post_method => queue}),
    ok = receive ok -> ok after 5000 -> timeout end,

    PRCommentsFun = match_fun("/repos/user/repo/pulls/1/comments",
                              get),
    meck:expect(hackney, send_request, PRCommentsFun),
    {ok, _} = egithub:pull_req_comments(Credentials, "user/repo", 1)
  after
    meck:unload(hackney)
  end.

issue_comments(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    IssueCommentFun = match_fun("/repos/user/repo/issues/1/comments", post),
    meck:expect(hackney, send_request, IssueCommentFun),
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    {ok, _} = egithub:issue_comment(Credentials, "user/repo", 1, "txt"),

    Self = self(),
    IssueCommentQueueFun = fun(_, {post, Url, _, _}) ->
                               "/repos/user/repo/issues/1/comments" =
                                 lists:flatten(Url),
                               Self ! ok,
                               {ok, 200, [], #client{}}
                           end,
    meck:expect(hackney, send_request, IssueCommentQueueFun),
    ok = egithub:issue_comment(Credentials, "user/repo", 1,
                               "txt", #{post_method => queue}),
    ok = receive ok -> ok after 5000 -> timeout end,

    IssueCommentsFun = match_fun("/repos/user/repo/issues/1/comments",
                                 get),
    meck:expect(hackney, send_request, IssueCommentsFun),
    {ok, _} = egithub:issue_comments(Credentials, "user/repo", 1)
  after
    meck:unload(hackney)
  end.

issues(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
      BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
      meck:expect(hackney, body, BodyReturnFun),
      CreateIssueFun = match_fun("/repos/user/repo/issues", post),
      meck:expect(hackney, send_request, CreateIssueFun),
      {ok, _} = egithub:create_issue(Credentials, "user", "repo", "title",
                                     "text", "user", ["bug"]),

      AllIssuesFun = match_fun("/issues", get),
      meck:expect(hackney, send_request, AllIssuesFun),
      {ok, _} = egithub:all_issues(Credentials, #{}),

      AllRepoIssuesFun = match_fun("/repos/user/repo/issues", get),
      meck:expect(hackney, send_request, AllRepoIssuesFun),
      {ok, _} = egithub:all_issues(Credentials, "user/repo", #{}),

      IssueUrl = "/issues?direction=asc&filter=assigned&"
                 "sort=created&state=open",
      AllIssuesOpenFun = match_fun(IssueUrl, get),
      meck:expect(hackney, send_request, AllIssuesOpenFun),
      {ok, _} = egithub:all_issues(Credentials, #{state => "open"}),

      UserIssuesFun = match_fun("/user/issues", get),
      meck:expect(hackney, send_request, UserIssuesFun),
      {ok, _} = egithub:issues_user(Credentials, #{}),

      OrgIssuesFun = match_fun("/orgs/foo/issues", get),
      meck:expect(hackney, send_request, OrgIssuesFun),
      {ok, _} = egithub:issues_org(Credentials, "foo", #{})

  after
      meck:unload(hackney)
  end.

files(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    FileContentFun = match_fun("/repos/user/repo/contents/file?ref=SHA", get),
    meck:expect(hackney, send_request, FileContentFun),
    BodyReturnFun = fun(_) -> {ok, <<"{\"content\" : \"\"}">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    {ok, _} = egithub:file_content(Credentials, "user/repo", "SHA", "file")
  after
    meck:unload(hackney)
  end.

users(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    UserFun = match_fun("/user", get),
    meck:expect(hackney, send_request, UserFun),
    {ok, _} = egithub:user(Credentials),

    GadgetCIFun = match_fun("/users/gadgetci", get),
    meck:expect(hackney, send_request, GadgetCIFun),
    {ok, _} = egithub:user(Credentials, "gadgetci"),

    EmailsFun = match_fun("/user/emails", get),
    meck:expect(hackney, send_request, EmailsFun),
    {ok, _} = egithub:user_emails(Credentials)
  after
    meck:unload(hackney)
  end.

orgs(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    OrgsFun = match_fun("/user/orgs", get),
    meck:expect(hackney, send_request, OrgsFun),
    {ok, _} = egithub:orgs(Credentials),

    OrgsUserFun = match_fun("/users/gadgetci/orgs", get),
    meck:expect(hackney, send_request, OrgsUserFun),
    {ok, _} = egithub:orgs(Credentials, "gadgetci"),

    OrgMembershipFun = match_fun("/user/memberships/orgs/some-organization",
                                 get),
    meck:expect(hackney, send_request, OrgMembershipFun),
    {ok, _} = egithub:org_membership(Credentials, "some-organization")
  after
    meck:unload(hackney)
  end.

repos(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    RepoFun = match_fun("/repos/inaka/whatever", get),
    meck:expect(hackney, send_request, RepoFun),
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    {ok, _} = egithub:repo(Credentials, "inaka/whatever"),

    ReposFun = match_fun("/user/repos?"
                         "type=all&sort=full_name&direction=asc&page=1",
                         get),
    meck:expect(hackney, send_request, ReposFun),
    {ok, _} = egithub:repos(Credentials, #{}),

    ReposUserFun = match_fun("/users/gadgetci/repos?page=1",
                             get),
    meck:expect(hackney, send_request, ReposUserFun),
    {ok, _} = egithub:repos(Credentials, "gadgetci", #{}),

    AllReposFun = match_fun("/user/repos?"
                             "type=all&sort=full_name&direction=asc&page=1",
                             get),
    meck:expect(hackney, send_request, AllReposFun),
    {ok, _} = egithub:all_repos(Credentials, #{}),
    BodyReturn1Fun = fun(_) -> {ok, <<"[1]">>} end,
    BodyReturnEmptyFun = fun(_) -> {ok, <<"[]">>} end,
    AllReposUserFun =
      fun(_, {get, Url, _, _}) ->
          case lists:flatten(Url) of
            "/users/gadgetci/repos?page=1" ->
              meck:expect(hackney, body, BodyReturn1Fun),
              {ok, 200, [], #client{}};
            "/users/gadgetci/repos?page=2" ->
              meck:expect(hackney, body, BodyReturnEmptyFun),
              {ok, 200, [], #client{}}
          end
      end,
    meck:expect(hackney, send_request, AllReposUserFun),
    {ok, _} = egithub:all_repos(Credentials, "gadgetci", #{}),

    AllReposErrorFun =
      fun(_, {get, Url, _, _}) ->
          case lists:flatten(Url) of
            "/users/gadgetci/repos?page=1" ->
              meck:expect(hackney, body, BodyReturn1Fun),
              {ok, 200, [], #client{}};
            "/users/gadgetci/repos?page=2" ->
              meck:expect(hackney, body, BodyReturnEmptyFun),
              {ok, 400, [], #client{}}
          end
      end,
    meck:expect(hackney, send_request, AllReposErrorFun),
    {error, _} = egithub:all_repos(Credentials, "gadgetci", #{}),

    OrgReposFun = match_fun("/orgs/some-org/repos?page=1&per_page=100", get),
    meck:expect(hackney, send_request, OrgReposFun),
    meck:expect(hackney, body, BodyReturnEmptyFun),
    {ok, _} = egithub:org_repos(Credentials, "some-org", #{}),

    AllOrgReposFun =
      fun(_, {get, Url, _, _}) ->
          case lists:flatten(Url) of
            "/orgs/some-org/repos?page=1&per_page=100" ->
              meck:expect(hackney, body, BodyReturn1Fun),
              {ok, 200, [], #client{}};
            "/orgs/some-org/repos?page=2&per_page=100" ->
              meck:expect(hackney, body, BodyReturnEmptyFun),
              {ok, 200, [], #client{}}
          end
      end,
    meck:expect(hackney, send_request, AllOrgReposFun),
    {ok, _} = egithub:all_org_repos(Credentials, "some-org", #{}),

    AllOrgReposErrorFun =
      fun(_, {get, Url, _, _})  ->
          case lists:flatten(Url) of
            "/orgs/some-org/repos?page=1&per_page=100" ->
              meck:expect(hackney, body, BodyReturn1Fun),
              {ok, 200, [], #client{}};
            "/orgs/some-org/repos?page=2&per_page=100" ->
              meck:expect(hackney, body, BodyReturnEmptyFun),
              {ok, 400, [], #client{}}
          end
      end,
    meck:expect(hackney, send_request, AllOrgReposErrorFun),
    {error, _} = egithub:all_org_repos(Credentials, "some-org", #{})
  after
    meck:unload(hackney)
  end.

teams(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    TeamsFun = match_fun("/orgs/some-org/teams", get),
    meck:expect(hackney, send_request, TeamsFun),
    {ok, _} = egithub:teams(Credentials, "some-org"),

    CreateTeamFun = match_fun("/orgs/some-org/teams", post),
    meck:expect(hackney, send_request, CreateTeamFun),
    {ok, _} = egithub:create_team(Credentials, "some-org", "Team", "", []),

    AddTeamRepoFun = match_fun("/teams/1/repos/user/repo",
                               put),
    meck:expect(hackney, send_request, AddTeamRepoFun),
    ok = egithub:add_team_repository(Credentials, 1, "user/repo"),

    AddTeamMemberFun = match_fun("/teams/1/members/gadgetci",
                                 put),
    meck:expect(hackney, send_request, AddTeamMemberFun),
    ok = egithub:add_team_member(Credentials, 1, "gadgetci"),

    DeleteTeamMemberFun = match_fun("/teams/1/members/gadgetci",
                                    delete),
    meck:expect(hackney, send_request, DeleteTeamMemberFun),
    ok = egithub:delete_team_member(Credentials, 1, "gadgetci"),

    TeamMembershipFun = match_fun("/teams/1/memberships/gadgetci", get),
    meck:expect(hackney, send_request, TeamMembershipFun),
    TeamMembershipBodyFun = fun(_) -> {ok, <<"{\"state\" : \"pending\"}">>} end,
    meck:expect(hackney, body, TeamMembershipBodyFun),
    pending = egithub:team_membership(Credentials, 1, "gadgetci")
  after
    meck:unload(hackney)
  end.

hooks(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    HooksFun = match_fun("/repos/some-repo/hooks", get),
    meck:expect(hackney, send_request, HooksFun),
    {ok, _} = egithub:hooks(Credentials, "some-repo"),

    CreateHookFun = match_fun("/repos/some-repo/hooks",
                              post),
    meck:expect(hackney, send_request, CreateHookFun),
    {ok, _} = egithub:create_webhook(Credentials, "some-repo",
                                     "url", ["pull_request"]),

    DeleteHookFun = match_fun("/repos/some-repo/hooks/url",
                              delete),
    meck:expect(hackney, send_request, DeleteHookFun),
    ok = egithub:delete_webhook(Credentials, "some-repo", "url")
  after
    meck:unload(hackney)
  end.

collaborators(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    CollaboratorsFun = match_fun("/repos/some-repo/collaborators", get),
    meck:expect(hackney, send_request, CollaboratorsFun),
    {ok, _} = egithub:collaborators(Credentials, "some-repo"),

    AddCollabFun = match_fun("/repos/some-repo/collaborators/username",
                             put),
    meck:expect(hackney, send_request, AddCollabFun),
    ok = egithub:add_collaborator(Credentials, "some-repo", "username"),

    DeleteCollabFun = match_fun("/repos/some-repo/collaborators/username",
                                delete),
    meck:expect(hackney, send_request, DeleteCollabFun),
    ok = egithub:remove_collaborator(Credentials, "some-repo", "username")
  after
    meck:unload(hackney)
  end.

statuses(_Config) ->
  Credentials = github_credentials(),

  meck:new(hackney, [passthrough]),
  try
    StatusesFun = match_fun("/repos/some-repo/commits/ref/statuses", get),
    BodyReturnFun = fun(_) -> {ok, <<"[]">>} end,
    meck:expect(hackney, body, BodyReturnFun),
    meck:expect(hackney, send_request, StatusesFun),
    {ok, _} = egithub:statuses(Credentials, "some-repo", "ref"),

    CreateStatusFun = match_fun("/repos/some-repo/statuses/SHA",
                                post),
    meck:expect(hackney, send_request, CreateStatusFun),
    {ok, _} = egithub:create_status(Credentials, "some-repo", "SHA", pending,
                                    "description", "context"),

    CreateStatusUrlFun = match_fun("/repos/some-repo/statuses/SHA",
                                   post),
    meck:expect(hackney, send_request, CreateStatusUrlFun),
    {ok, _} = egithub:create_status(Credentials, "some-repo", "SHA", pending,
                                    "description", "context", "url"),

    CombinedStatusFun = match_fun("/repos/some-repo/commits/ref/status",
                                  get),
    meck:expect(hackney, send_request, CombinedStatusFun),
    {ok, _} = egithub:combined_status(Credentials, "some-repo", "ref")
  after
    meck:unload(hackney)
  end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Helper
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec github_credentials() -> {'basic', string(), string()}.
github_credentials() ->
  egithub:basic_auth("username", "password").

match_fun(Url, Method) ->
  fun(_, {MethodParam, UrlParam, _, _}) ->
      Url = lists:flatten(UrlParam),
      Method = MethodParam,
      RespHeaders = [],
      ClientRef = #client{},
      {ok, 200, RespHeaders, ClientRef}
  end.
