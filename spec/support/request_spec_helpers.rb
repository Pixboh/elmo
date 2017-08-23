module RequestSpecHelpers
  # Currently duplicated in test/test_helper until it becomes obvious how to refactor.
  def login(user)
    login_without_redirect(user)
    follow_redirect!
    assert_response(:success)
    user.reload # Some stuff may have changed in database during login process
  end

  def login_without_redirect(user)
    post("/en/user-session", user_session: {login: user.login, password: test_password})
  end

  def logout
    delete("/en/user-session")
    follow_redirect!
  end

  def do_api_request(endpoint, params = {})
    params[:user] ||= @api_user
    params[:mission_name] ||= @mission.compact_name

    path_args = [{mission_name: params[:mission_name]}]
    path_args.unshift(params[:obj]) if params[:obj]
    path = send("api_v1_#{endpoint}_path", *path_args)

    get path, params[:params], {"HTTP_AUTHORIZATION" => "Token token=#{params[:user].api_key}"}
  end

  def get_s(*args)
    get *args
    assert_response(:success)
  end

  def post_s(*args)
    post *args
    assert_response(:success)
  end
end
