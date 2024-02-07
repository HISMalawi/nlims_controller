module UserService
  def self.create_user(params)
    location = params[:location]
    app_name = params[:app_name]
    password = params[:password]
    username = params[:username]
    token = params[:token]
    partner = params[:partner]

    details = compute_expiry_time
    token = details[:token]
    expiry_time = details[:expiry_time]
    password = encrypt_password(password)

    User.create(app_name: app_name,
                partner: partner,
                location: location,
                password: password,
                username: username,
                token: token,
                token_expiry_time: expiry_time)

    { token: token, expiry_time: expiry_time }
  end

  def self.check_account_creation_request(token)
    tokens = JSON.parse(File.read("#{Rails.root}/tmp/nlims_account_creating_token.json"))
    return true if tokens['tokens'].include?(token)

    false
  end

  def self.create_token
    token_chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    token_length = 12
    Array.new(token_length) { token_chars[rand(token_chars.length)] }.join
  end

  def self.compute_expiry_time
    token = create_token
    time = Time.now
    time += 14_400
    { token: token, expiry_time: time.strftime('%Y%m%d%H%M%S') }
  end

  def self.check_token(token)
    user = User.where(token: token).first

    return false unless user
    return true if user.token_expiry_time > Time.now.strftime('%Y%m%d%H%M%S')

    false
  end

  def self.authenticate(username, password)
    user = User.where(username: username).first

    return false unless user

    secured_pass = BCrypt::Password.new(user['password'])
    return true if secured_pass == password

    false
  end

  def self.prepare_token_for_account_creation(token)
    unless File.exist?("#{Rails.root}/tmp/nlims_account_creating_token.json")
      header = {}
      FileUtils.touch "#{Rails.root}/tmp/nlims_account_creating_token.json"
      header['tokens'] = ['0']
      File.open("#{Rails.root}/tmp/nlims_account_creating_token.json", 'w') do |f|
        f.write(header.to_json)
      end
    end
    tokens = JSON.parse(File.read("#{Rails.root}/tmp/nlims_account_creating_token.json"))
    tokens['tokens'].push(token)
    File.open("#{Rails.root}/tmp/nlims_account_creating_token.json", 'w') do |f|
      f.write(tokens.to_json)
    end
  end

  def self.check_user(username)
    user = User.where(username: username).first
    return true if user

    false
  end

  def self.re_authenticate(username, password)
    user = User.where(username: username).first
    token = create_token
    expiry_time = compute_expiry_time

    return false unless user

    secured_pass = decrypt_password(user.password)
    return false unless secured_pass == password

    User.update(user.id, token: token, token_expiry_time: expiry_time[:expiry_time])
    { token: token, expiry_time: expiry_time[:expiry_time] }
  end

  def self.encrypt_password(password)
    BCrypt::Password.create(password)
  end

  def self.decrypt_password(password)
    BCrypt::Password.new(password)
  end
end
