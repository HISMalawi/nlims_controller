# frozen_string_literal: true

MASTER_IP_ADDRESS = 'localhost'

Config.find_or_create_by(config_type: 'nlims_host').update(configs: { local_nlims: true })
users = [
  {
    username: 'local_nlims_lab_daemon',
    password: '$2a$12$k708Qyc8ngOojEssGKanAuRYBA8asg0K3FZHoT2VQ/h9tmAhEdE5y',
    app_name: 'LOCAL NLIMS',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: '008aa778-af95-42d5-ba54-2f5ddc4f9e78'
  },
  {
    username: 'master_nlims_lab_daemon',
    password: '$2a$12$k708Qyc8ngOojEssGKanAuRYBA8asg0K3FZHoT2VQ/h9tmAhEdE5y',
    app_name: 'MASTER NLIMS',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: 'c1bcdaa3-a835-4481-84dc-92dace6bea59'
  },
  {
    username: 'emr_nlims_lab_daemon',
    password: '$2a$12$k708Qyc8ngOojEssGKanAuRYBA8asg0K3FZHoT2VQ/h9tmAhEdE5y',
    app_name: 'EMR',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: 'a6a52ccb-8215-45d8-90dc-826ee12f4055'
  },
  {
    username: 'mahis_nlims_lab_daemon',
    password: '$2a$12$k708Qyc8ngOojEssGKanAuRYBA8asg0K3FZHoT2VQ/h9tmAhEdE5y',
    app_name: 'MAHIS',
    partner: 'DHD',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: '2d299a0b-327a-4be0-b44d-bd3385303224'
  },
  {
    username: 'iblis_nlims_lab_daemon',
    password: '$2a$12$k708Qyc8ngOojEssGKanAuRYBA8asg0K3FZHoT2VQ/h9tmAhEdE5y',
    app_name: 'IBLIS',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: '44d75135-7bf0-407e-94ec-8cf2edb7e652'
  }
]
users.each do |user|
  user_obj = User.find_by_username(user[:username])
  user_obj ||= User.create!(user)
  user_obj&.update(user)
end

if Config.local_nlims?
  Config.find_or_create_by(config_type: 'master_nlims')
        .update(
          configs: {
            name: 'MASTER NLIMS',
            address: "http://#{MASTER_IP_ADDRESS}",
            port: 3010,
            username: 'local_nlims_lab_daemon'
          }
        )
  Config.find_or_create_by(config_type: 'emr')
        .update(
          configs: {
            name: 'EMR',
            address: 'http://localhost',
            port: 3002,
            username: 'emr_app_daemon'
          }
        )
  Config.find_or_create_by(config_type: 'mahis')
        .update(
          configs: {
            name: 'MAHIS',
            address: 'http://localhost',
            port: 3002,
            username: 'mahis_app_daemon'
          }
        )
else
  Config.find_or_create_by(config_type: 'local_nlims')
        .update(
          configs: {
            name: 'LOCAL NLIMS',
            address: 'http://localhost',
            port: 3009,
            username: 'master_nlims_lab_daemon'
          }
        )
end
