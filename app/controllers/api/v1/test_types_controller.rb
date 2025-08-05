# frozen_string_literal: true

module API
  module V1
    class TestTypesController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_frontend_ui_service,
                    only: %i[create show edit update destroy approve_test_catalog retrieve_test_catalog
                             new_test_catalog_version_available retrieve_test_catalog_versions import]
      before_action :set_test_type, only: %i[show update destroy]

      # Rescue from BadRequest errors (like invalid % encoding)
      rescue_from ActionController::BadRequest do |e|
        render json: {
          success: false,
          error: "Bad request: #{e.message}. The file might contain special characters. Please ensure the file is properly encoded."
        }, status: :bad_request
      end

      def index
        @test_types = TestType.all

        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @test_types = @test_types.where(
            'name LIKE ? OR short_name LIKE ? OR preferred_name LIKE ? OR scientific_name LIKE ?',
            search_term, search_term, search_term, search_term
          )
        end

        @test_types = @test_types.where(test_category_id: params[:test_category_id]) if params[:test_category_id].present?
        @test_types = @test_types.where(can_be_done_on_sex: params[:sex]) if params[:sex].present?
        @test_types = @test_types.where('targetTAT LIKE ?', "%#{params[:target_tat]}%") if params[:target_tat].present?
        @test_types = @test_types.where('moh_code LIKE ?', "%#{params[:moh_code]}%") if params[:moh_code].present?
        @test_types = @test_types.where('nlims_code LIKE ?', "%#{params[:nlims_code]}%") if params[:nlims_code].present?
        @test_types = @test_types.where('loinc_code LIKE ?', "%#{params[:loinc_code]}%") if params[:loinc_code].present?
        @test_types = @test_types.where('assay_format LIKE ?', "%#{params[:assay_format]}%") if params[:assay_format].present?
        @test_types = @test_types.where('hr_cadre_required LIKE ?', "%#{params[:hr_cadre_required]}%") if params[:hr_cadre_required].present?

        if params[:specimen_type_id].present?
          @test_types = @test_types.joins(:testtype_specimentypes)
                                   .where(testtype_specimentypes: { specimen_type_id: params[:specimen_type_id] })
        end

        @test_types = @test_types.order(:name)

        if params[:no_paginate].present? && params[:no_paginate].to_s.downcase == 'true'
          render json: @test_types
        else
          page = params[:page]&.to_i || 1
          per_page = params[:per_page]&.to_i || 25
          per_page = [per_page, 100].min

          total_count = @test_types.count
          @test_types = @test_types.offset((page - 1) * per_page).limit(per_page)

          render json: {
            data: @test_types,
            pagination: {
              current_page: page,
              per_page: per_page,
              total_count: total_count,
              total_pages: (total_count.to_f / per_page).ceil
            }
          }
        end
      end

      def show
        render json: @test_type.as_json(context: :single_item)
      end

      def create
        @test_type = TestCatalogService.create_test_type(test_type_params)
        render json: @test_type.as_json(context: :single_item), status: :created
      end

      def import
        if params[:file].nil?
          render json: { success: false, error: 'No file uploaded' }, status: :unprocessable_entity
          return
        end

        begin
          uploaded_file = params[:file]
          safe_filename = uploaded_file.original_filename.encode('UTF-8', invalid: :replace, undef: :replace, replace: '_')
          file_ext = File.extname(safe_filename).downcase

          excel_mime_types = [
            'application/vnd.ms-excel',
            'application/msexcel',
            'application/x-msexcel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-excel.sheet.macroEnabled.12',
            'application/vnd.ms-excel.sheet.binary.macroEnabled.12'
          ]

          is_acceptable_extension = %w[.xls .xlsx].include?(file_ext)

          content_type = uploaded_file.content_type rescue nil
          content_type ||= case file_ext
                         when '.xls'
                           'application/vnd.ms-excel'
                         when '.xlsx'
                           'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                         else
                           'application/octet-stream'
                         end

          unless excel_mime_types.include?(content_type) || is_acceptable_extension
            render json: {
              success: false,
              error: 'Invalid file format. Please upload an Excel file',
              details: {
                content_type: content_type,
                extension: file_ext
              }
            }, status: :unprocessable_entity
            return
          end

          temp_file = Tempfile.new(['import', file_ext])
          begin
            uploaded_io = uploaded_file.respond_to?(:tempfile) ? uploaded_file.tempfile : uploaded_file
            file_content = nil

            begin
              file_content = File.binread(uploaded_io.path)
            rescue => e
              uploaded_io.rewind rescue nil
              file_content = uploaded_io.read rescue nil

              unless file_content
                raise "Could not read file content: #{e.message}"
              end
            end

            temp_file.binmode
            temp_file.write(file_content)
            temp_file.rewind

            temp_file.instance_eval do
              def original_filename
                "import#{File.extname(path)}"
              end

              def content_type
                case File.extname(path).downcase
                when '.xls'
                  'application/vnd.ms-excel'
                when '.xlsx'
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                else
                  'application/octet-stream'
                end
              end
            end

            result = TestCatalogService.import(temp_file)

            if result[:success]
              render json: result, status: :ok
            else
              render json: result, status: :unprocessable_entity
            end
          ensure
            begin
              temp_file.close
              temp_file.unlink
            rescue => e
              Rails.logger.error("Error cleaning up temp file: #{e.message}")
            end
          end
        rescue ActionController::BadRequest => e
          raise e
        rescue => e
          Rails.logger.error("Import error: #{e.message}\n#{e.backtrace.join("\n")}")

          error_message = case e.message
                         when /invalid byte sequence/
                           "The file contains invalid characters. Please save it as UTF-8 encoded and try again."
                         when /premature end of data/
                           "The Excel file appears to be corrupt or improperly formatted. Please check the file format."
                         when /unknown encoding name/
                           "Could not determine the file encoding. Please save the file as UTF-8 and try again."
                         else
                           "Error processing file: #{e.message}"
                         end

          render json: {
            success: false,
            error: error_message,
            details: e.backtrace.first(5)
          }, status: :unprocessable_entity
        end
      end

      def update
        TestCatalogService.update_test_type(@test_type, test_type_params)
        render json: @test_type.as_json(context: :single_item), status: :ok
      end

      def measures
        @measures = if params[:search].present?
                      Measure.where('name LIKE ?', "%#{params[:search]}%")
                    else
                      Measure.all
                    end
        render json: @measures
      end

      def measure_types
        @measure_types = if params[:search].present?
                           MeasureType.where('name LIKE ?', "%#{params[:search]}%")
                         else
                           MeasureType.all
                         end
        render json: @measure_types
      end

      def approve_test_catalog
        approved = TestCatalogService.approve_test_catalog(params.require(:version_details))
        render json: approved
      end

      def retrieve_test_catalog
        render json: TestCatalogService.retrieve_test_catalog(params[:version])
      end

      def retrieve_test_catalog_versions
        render json: TestCatalogService.test_catalog_versions
      end

      def new_test_catalog_version_available
        previous_version = TestCatalogVersion.find_by(version: params[:version])&.version || '0'
        render json: TestCatalogService.new_version_available?(previous_version)
      end

      def destroy
        @test_type.destroy
        render json: { message: 'Test type deleted successfully' }, status: :ok
      end

      private

      def test_type_params
        params.require(:test_catalog).permit(
          test_type: %i[
            name short_name description loinc_code moh_code nlims_code
            targetTAT preferred_name scientific_name can_be_done_on_sex test_category_id
            assay_format hr_cadre_required iblis_mapping_name
          ],
          specimen_types: [],
          measures: [
            :id, :name, :short_name, :unit, :measure_type_id, :description, :loinc_code,
            :moh_code, :nlims_code, :preferred_name, :scientific_name, :iblis_mapping_name,
            { measure_ranges_attributes: %i[
              id age_min age_max range_lower range_upper sex value interpretation
            ] }
          ],
          organisms: [],
          lab_test_sites: [],
          equipment: []
        )
      end

      def set_test_type
        @test_type = TestType.find(params[:id])
      end
    end
  end
end
