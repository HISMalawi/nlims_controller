# frozen_string_literal: true

MASTER_IP_ADDRESS = '10.44.0.46'

Config.find_or_create_by(config_type: 'nlims_host').update(configs: { local_nlims: true })

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
            username: 'emr_lab_daemon'
          }
        )
  Config.find_or_create_by(config_type: 'mahis')
        .update(
          configs: {
            name: 'MAHIS',
            address: 'http://localhost',
            port: 3002,
            username: 'mahis_lab_daemon'
          }
        )
else
  Config.find_or_create_by(config_type: 'local_nlims')
        .update(
          configs: {
            name: 'LOCAL NLIMS',
            address: 'http://localhost',
            port: 3009,
            username: 'local_nlims_lab_daemon'
          }
        )
end
