module UserService
  def self.create_user(params)
    details = compute_expiry_time
    user = User.create!(
      app_name: params[:app_name],
      partner: params[:partner],
      location: params[:location],
      password: encrypt_password(params[:password]),
      username: params[:username],
      token: details[:token],
      app_uuid: params[:app_uuid],
      token_expiry_time: details[:expiry_time]
    )
    if params[:roles].present?
      params[:roles].each do |role|
        user.roles << Role.find_by(name: role)
      end
    else
      user.roles << Role.find_by(name: 'system')
    end
    { token: details[:token], expiry_time: details[:expiry_time], roles: user.roles.pluck(:name) }
  end

  def self.check_account_creation_request(token)
    tokens = JSON.parse(File.read("#{Rails.root}/tmp/nlims_account_creating_token.json"))
    return true if tokens['tokens'].include?(token)

    false
  end

  def self.remove_tokens_for_account_creation
    file_path = "#{Rails.root}/tmp/nlims_account_creating_token.json"
    begin
      tokens = JSON.parse(File.read(file_path))
    rescue StandardError => e
      Rails.logger.error("Error reading tokens file: #{e.message}")
      File.write(file_path, { 'tokens' => ['0'] }.to_json)
      tokens = { 'tokens' => ['0'] }
    end
    return unless tokens['tokens'].length > 10

    header = {}
    File.write(file_path, { 'tokens' => [] }.to_json)
    header['tokens'] = ['0']
    File.write(file_path, header.to_json)
  end

  def self.create_token
    # token_chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    # token_length = 12
    # Array.new(token_length) { token_chars[rand(token_chars.length)] }.join
    SecureRandom.uuid
  end

  def self.compute_expiry_time
    token = create_token
    time = Time.now
    time += 24.hours
    { token:, expiry_time: time.strftime('%Y%m%d%H%M%S') }
  end

  def self.check_token(token)
    user = User.where(token:).first
    return false unless user
    return false unless user.token_expiry_time.present?
    return true if user.token_expiry_time > Time.now.strftime('%Y%m%d%H%M%S')

    false
  end

  def self.authenticate(username, password)
    user = User.where(username:).first

    return false if user.nil?

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
    remove_tokens_for_account_creation
    tokens = JSON.parse(File.read("#{Rails.root}/tmp/nlims_account_creating_token.json"))
    tokens['tokens'].push(token)
    File.open("#{Rails.root}/tmp/nlims_account_creating_token.json", 'w') do |f|
      f.write(tokens.to_json)
    end
  end

  def self.check_user(username)
    user = User.where(username:).first
    return true if user

    false
  end

  def self.re_authenticate(username, password)
    user = User.where(username:).first
    token_valid = check_token(user.token) if user

    token = token_valid ? user.token : create_token
    expiry_time = compute_expiry_time

    return false unless user

    secured_pass = decrypt_password(user.password)
    return false unless secured_pass == password

    User.update(user.id, token:, token_expiry_time: expiry_time[:expiry_time])
    { token:, expiry_time: expiry_time[:expiry_time] }
  end

  def self.refresh_token(app_uuid)
    user = User.find_by(app_uuid:)
    return false if user.nil?

    token = create_token
    expiry_time = compute_expiry_time

    User.update(user.id, token:, token_expiry_time: expiry_time[:expiry_time])
    { token:, expiry_time: expiry_time[:expiry_time] }
  end

  def self.encrypt_password(password)
    BCrypt::Password.create(password)
  end

  def self.decrypt_password(password)
    BCrypt::Password.new(password)
  end
end
