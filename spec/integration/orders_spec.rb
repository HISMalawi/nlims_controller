# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Orders API', type: :request do
  path '/api/v2/orders' do
    post 'Create a new laboratory order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [tokenAuth: []]
      description 'Create a new laboratory order'
      parameter name: :order_payload, in: :body, schema: {
        type: :object,
        required: %w[order patient tests],
        properties: {
          order: {
            type: :object,
            required: %w[
              district
              sending_facility
              tracking_number
              requested_by
              date_created
              priority
              target_lab
              order_location
              sample_type
              sample_status
              drawn_by
            ],
            properties: {
              uuid: { type: :string },
              tracking_number: { type: :string },
              district: { type: :string },
              sending_facility: { type: :string },
              requested_by: { type: :string },
              date_created: { type: :string, format: 'date-time' },
              priority: { type: :string },
              target_lab: { type: :string },
              order_location: { type: :string },
              reason_for_test: { type: :string },
              art_start_date: { type: :string },
              arv_number: { type: :string },
              art_regimen: { type: :string },
              clinical_history: { type: :string },
              lab_location: { type: :string },
              source_system: { type: :string },

              sample_type: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string },
                  nlims_code: { type: :string }
                }
              },

              sample_status: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string }
                }
              },

              drawn_by: {
                type: :object,
                required: %w[name],
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  phone_number: { type: :string }
                }
              },

              status_trail: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    status: { type: :string },
                    timestamp: { type: :string, format: 'date-time' },
                    updated_by: {
                      type: :object,
                      properties: {
                        first_name: { type: :string },
                        last_name: { type: :string },
                        id_number: { type: :string },
                        phone_number: { type: :string }
                      }
                    }
                  }
                }
              }
            }
          },

          patient: {
            type: :object,
            required: %w[first_name last_name gender date_of_birth],
            properties: {
              national_patient_id: { type: :string },
              first_name: { type: :string },
              last_name: { type: :string },
              gender: { type: :string },
              date_of_birth: { type: :string },
              phone_number: { type: :string }
            }
          },

          tests: {
            type: :array,
            description: 'Required: tests not provided',
            items: {
              type: :object,
              required: %w[test_status test_type],
              properties: {
                test_status: { type: :string },
                time_updated: { type: :string, format: 'date-time' },
                test_type: {
                  type: :object,
                  required: %w[name nlims_code],
                  properties: {
                    name: { type: :string },
                    nlims_code: { type: :string }
                  }
                },
                test_results: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      measure: {
                        type: :object,
                        required: %w[name nlims_code],
                        properties: {
                          name: { type: :string },
                          nlims_code: { type: :string }
                        }
                      },
                      result: {
                        type: :object,
                        required: %w[value result_date],
                        properties: {
                          value: { type: :string },
                          unit: { type: :string },
                          result_date: { type: :string, format: 'date-time' },
                          platform: { type: :string },
                          platformserial: { type: :string }
                        }
                      }
                    }
                  }
                },
                status_trail: {
                  type: :array,
                  items: {
                    type: :object,
                    required: %w[status timestamp],
                    properties: {
                      status: { type: :string },
                      timestamp: { type: :string, format: 'date-time' },
                      updated_by: {
                        type: :object,
                        properties: {
                          first_name: { type: :string },
                          last_name: { type: :string },
                          id_number: { type: :string },
                          phone_number: { type: :string }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        example: {
          order: {
            uuid: '3452b6d0-acca-4d9e-9052-7acee4f646fc',
            tracking_number: 'XTRK123495',
            sample_type: { name: 'Plasma', nlims_code: 'NLIMS_SP_0017_MWI' },
            sample_status: { name: 'specimen_collected' },
            order_location: 'OPD',
            date_created: '2025-09-13 02:00:00',
            priority: 'Routine',
            reason_for_test: 'Invistration',
            drawn_by: { id: 1001, name: 'John Doe', phone_number: '+265999111222' },
            target_lab: 'National Reference Lab',
            sending_facility: 'Kamuzu Central Hospital',
            district: 'Lilongwe',
            requested_by: 'Dr. Delete',
            art_start_date: '2020-05-10',
            arv_number: 'ARV-998877',
            art_regimen: 'TDF/3TC/DTG',
            clinical_history: 'allergic to nuts',
            lab_location: 'Main Lab',
            source_system: 'IBLIS',
            status_trail: [
              {
                status: 'specimen_collected',
                timestamp: '2025-09-13 02:00:00',
                updated_by: { first_name: 'Xmachina', last_name: 'Delete', id_number: '38', phone_number: '' }
              }
            ]
          },
          patient: {
            national_patient_id: 'PAT-123456',
            first_name: 'Mary',
            last_name: 'Chirwa',
            date_of_birth: '1992-03-21',
            gender: 'F',
            phone_number: '+265888777666'
          },
          tests: [
            {
              test_status: 'verified',
              time_updated: '2025-09-13 02:00:00',
              test_type: { name: 'HIV Viral Load', nlims_code: 'NLIMS_TT_0071_MWI' },
              test_results: [
                {
                  measure: { name: 'Viral Load', nlims_code: 'NLIMS_TI_0294_MWI' },
                  result: { value: '100', unit: 'copies/mL', result_date: '2025-09-13 04:10:02', platform: 'Abbot',
                            platformserial: '275021258' }
                }
              ],
              status_trail: [
                {
                  status: 'started',
                  timestamp: '2025-09-13 02:00:00',
                  updated_by: { first_name: 'Xmachina', last_name: 'Delete', id_number: '38', phone_number: '' }
                },
                {
                  status: 'completed',
                  timestamp: '2025-09-13 03:00:00',
                  updated_by: { first_name: 'Xmachina', last_name: 'Delete', id_number: '38', phone_number: '' }
                }
              ]
            }
          ]
        }
      }

      response '200', 'order successfully created' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'order successfully created' },
                 data: {
                   type: :object,
                   properties: {
                     tracking_number: { type: :string, example: 'XTRK123495' }
                   }
                 }
               }
        run_test!
      end

      response '422', 'Error: Unprocessable Entity' do
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: true },
                 message: { type: :string, example: 'tracking number not provided' },
                 data: { type: :object, example: {} }
               }
        run_test!
      end
    end
  end
  path '/api/v2/orders/{tracking_number}' do
    get 'Find an order by tracking number' do
      tags 'Orders'
      produces 'application/json'
      security [tokenAuth: []]

      parameter name: :tracking_number, in: :path, type: :string, required: true,
                description: 'Tracking number of the order'

      response '200', 'Order Found' do
        description 'Returns the order, patient, and tests data'
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: false },
                 message: { type: :string, example: 'Order Found' },
                 data: {
                   type: :object,
                   properties: {
                     order: {
                       type: :object,
                       properties: {
                         uuid: { type: :string },
                         tracking_number: { type: :string },
                         sample_type: {
                           type: :object,
                           properties: {
                             id: { type: :integer },
                             name: { type: :string },
                             nlims_code: { type: :string }
                           }
                         },
                         sample_status: {
                           type: :object,
                           properties: {
                             id: { type: :integer },
                             name: { type: :string }
                           }
                         },
                         order_location: { type: :string },
                         date_created: { type: :string, format: 'date-time' },
                         priority: { type: :string },
                         reason_for_test: { type: :string },
                         drawn_by: {
                           type: :object,
                           properties: {
                             id: { type: :string },
                             name: { type: :string },
                             phone_number: { type: :string }
                           }
                         },
                         target_lab: { type: :string },
                         sending_facility: { type: :string },
                         district: { type: :string },
                         site_code_number: { type: :string },
                         requested_by: { type: :string },
                         art_start_date: { type: :string },
                         arv_number: { type: :string },
                         art_regimen: { type: :string },
                         clinical_history: { type: :string },
                         lab_location: { type: :string },
                         source_system: { type: :string },
                         status_trail: {
                           type: :array,
                           items: {
                             type: :object,
                             properties: {
                               status_id: { type: :integer },
                               status: { type: :string },
                               timestamp: { type: :string, format: 'date-time' },
                               updated_by: {
                                 type: :object,
                                 properties: {
                                   first_name: { type: :string },
                                   last_name: { type: :string },
                                   id: { type: :string },
                                   phone_number: { type: :string }
                                 }
                               }
                             }
                           }
                         }
                       }
                     },
                     patient: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         national_patient_id: { type: :string },
                         first_name: { type: :string },
                         last_name: { type: :string },
                         gender: { type: :string },
                         date_of_birth: { type: :string },
                         phone_number: { type: :string }
                       }
                     },
                     tests: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           tracking_number: { type: :string },
                           arv_number: { type: :string },
                           uuid: { type: :string },
                           test_status: { type: :string },
                           time_updated: { type: :string, format: 'date-time' },
                           test_type: {
                             type: :object,
                             required: %w[name nlims_code],
                             properties: {
                               name: { type: :string },
                               nlims_code: { type: :string }
                             }
                           },
                           status_trail: {
                             type: :array,
                             items: {
                               type: :object,
                               properties: {
                                 status_id: { type: :integer },
                                 status: { type: :string },
                                 timestamp: { type: :string, format: 'date-time' },
                                 updated_by: {
                                   type: :object,
                                   properties: {
                                     first_name: { type: :string },
                                     last_name: { type: :string },
                                     id: { type: :string },
                                     phone_number: { type: :string }
                                   }
                                 }
                               }
                             }
                           },
                           test_results: {
                             type: :array,
                             items: {
                               type: :object,
                               properties: {
                                 measure: {
                                   type: :object,
                                   properties: {
                                     name: { type: :string },
                                     nlims_code: { type: :string }
                                   }
                                 },
                                 result: {
                                   type: :object,
                                   properties: {
                                     value: { type: :string },
                                     unit: { type: :string },
                                     result_date: { type: :string, format: 'date-time' },
                                     platform: { type: :string },
                                     platformserial: { type: :string }
                                   }
                                 }
                               }
                             }
                           }
                         }
                       }
                     }
                   }
                 }
               }
        run_test!
      end

      response '404', 'Order Not Available' do
        description 'Returned when the order cannot be found'
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: true },
                 message: { type: :string, example: 'Order Not Available' },
                 data: { type: :object, example: {} }
               }
        run_test!
      end
    end
  end

  path '/api/v2/orders/{tracking_number}' do
    put 'Update an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [tokenAuth: []]

      parameter name: :tracking_number, in: :path, type: :string, required: true

      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[status time_updated status_trail],
        properties: {
          status: { type: :string },
          time_updated: { type: :string, format: 'date-time' },
          sample_type: {
            type: :object,
            required: %w[name nlims_code],
            properties: {
              name: { type: :string },
              nlims_code: { type: :string }
            }
          },
          status_trail: {
            type: :array,
            items: {
              type: :object,
              required: %w[status timestamp updated_by],
              properties: {
                status: { type: :string },
                timestamp: { type: :string, format: 'date-time' },
                updated_by: {
                  type: :object,
                  required: %w[first_name last_name id],
                  properties: {
                    first_name: { type: :string },
                    last_name: { type: :string },
                    id: { type: :string },
                    phone_number: { type: :string }
                  }
                }
              }
            }
          }
        }
      }

      response '200', 'Order Updated' do
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: false },
                 message: { type: :string, example: 'order updated successfully' },
                 data: { type: :object, example: { tracking_number: 'XTRK123495' } }
               }
        run_test!
      end

      response '422', 'Unprocessable Entity' do
        schema(
          oneOf: [
            schema_error('time updated or result date provided is in the past'),
            schema_error('status trail not provided'),
            schema_error('specimen type not available in nlims for'),
            schema_error('specimen status not available in nlims - available statuses are [specimen_not_collected, specimen_accepted, specimen_rejected, specimen_collected, sample_accepted_at_hub, sample_rejected_at_hub, sample_accepted_at_ml, sample_rejected_at_ml]')
          ]
        )
        run_test!
      end
    end
  end

  path '/api/v2/orders/{tracking_number}/exists' do
    get 'Check if an order exists' do
      tags 'Orders'
      produces 'application/json'
      security [tokenAuth: []]

      parameter name: :tracking_number, in: :path, type: :string, required: true,
                description: 'Tracking number of the order'

      response '200', 'Order Exists' do
        description 'Returns true if the order exists'
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: false },
                 message: { type: :string, example: 'Order Exists' },
                 data: { type: :boolean, example: true }
               }
        run_test!
      end
    end
  end

  path '/api/v2/orders/tracking_numbers/all' do
    get 'Get tracking numbers to be logged for validation of orders against master' do
      tags 'Orders'
      produces 'application/json'
      security [tokenAuth: []]

      parameter name: :order_id, in: :query, type: :integer, required: true, description: 'Order ID'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Limit of records to return (max 50000, default 50000)'
      parameter name: :from, in: :query, type: :string, required: false, description: 'From date'

      response '200', 'Tracking numbers returned' do
        description 'Returns the tracking numbers'
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   tracking_number: { type: :string }
                 }
               }
        run_test!
      end
    end
  end

  path '/api/v2/orders/requests' do
    post 'Request an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [tokenAuth: []]

      parameter name: :order_payload, in: :body, schema: {
        type: :object,
        required: %w[order patient tests],
        properties: {
          order: {
            type: :object,
            required: %w[
              district
              sending_facility
              tracking_number
              requested_by
              date_created
              priority
              target_lab
              order_location
              sample_status
              drawn_by
            ],
            properties: {
              uuid: { type: :string },
              tracking_number: { type: :string },
              district: { type: :string },
              sending_facility: { type: :string },
              requested_by: { type: :string },
              date_created: { type: :string, format: 'date-time' },
              priority: { type: :string },
              target_lab: { type: :string },
              order_location: { type: :string },
              reason_for_test: { type: :string },
              art_start_date: { type: :string },
              arv_number: { type: :string },
              art_regimen: { type: :string },
              clinical_history: { type: :string },
              lab_location: { type: :string },
              source_system: { type: :string },
              sample_status: {
                type: :object,
                required: %w[name],
                properties: {
                  name: { type: :string }
                }
              },

              drawn_by: {
                type: :object,
                required: %w[name],
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  phone_number: { type: :string }
                }
              },

              status_trail: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    status: { type: :string },
                    timestamp: { type: :string, format: 'date-time' },
                    updated_by: {
                      type: :object,
                      properties: {
                        first_name: { type: :string },
                        last_name: { type: :string },
                        id_number: { type: :string },
                        phone_number: { type: :string }
                      }
                    }
                  }
                }
              }
            }
          },
          patient: {
            type: :object,
            required: %w[first_name last_name gender date_of_birth],
            properties: {
              national_patient_id: { type: :string },
              first_name: { type: :string },
              last_name: { type: :string },
              gender: { type: :string },
              date_of_birth: { type: :string },
              phone_number: { type: :string }
            }
          },
          tests: {
            type: :array,
            description: 'Required: tests not provided',
            items: {
              type: :object,
              required: %w[test_type],
              properties: {
                time_updated: { type: :string, format: 'date-time' },
                test_type: {
                  type: :object,
                  required: %w[name nlims_code],
                  properties: {
                    name: { type: :string },
                    nlims_code: { type: :string }
                  }
                }
              }
            }
          }
        }
      }

      response '201', 'Order Created' do
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: false },
                 message: { type: :string, example: 'order created successfully' },
                 data: {
                   type: :object,
                   properties: {
                     tracking_number: { type: :string, example: 'XTRK123495' },
                     uuid: { type: :string, example: '1234567890' }
                   }
                 }
               }
        run_test!
      end
    end
  end

  path '/api/v2/orders/requests/{tracking_number}' do
    put 'Confirm an order request' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [tokenAuth: []]

      parameter name: :tracking_number, in: :path, type: :string, required: true

      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[sample_type],
        properties: {
          sample_type: {
            type: :object,
            required: %w[nlims_code],
            properties: {
              nlims_code: { type: :string }
            }
          },
          target_lab: { type: :string }
        }
      }

      response '200', 'Order Confirmed' do
        schema type: :object,
               properties: {
                 error: { type: :boolean, example: false },
                 message: { type: :string, example: 'order confirmed successfully' },
                 data: { type: :object, example: { tracking_number: 'XTRK123495' } }
               }
        run_test!
      end
    end
  end
end
