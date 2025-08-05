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
        @test_types = if params[:search].present?
                        TestType.where('name LIKE ?', "%#{params[:search]}%").orWhere('short_name LIKE ?', "%#{params[:search]}%").orWhere(
                          'preferred_name LIKE ?', "%#{params[:search]}%"
                        )
                      else
                        TestType.all
                      end
        render json: @test_types.order(:name)
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
          # Get the file from the request
          uploaded_file = params[:file]

          # Write to a temp file with a sanitized name to avoid encoding issues
          safe_filename = uploaded_file.original_filename.encode('UTF-8', invalid: :replace, undef: :replace, replace: '_')
          file_ext = File.extname(safe_filename).downcase

          # Broader acceptance of MIME types for CSV/Excel files
          csv_mime_types = [
            'text/csv',
            'application/csv',
            'application/x-csv',
            'text/comma-separated-values',
            'text/x-csv',
            'text/plain' # Sometimes CSV files are uploaded as text/plain
          ]

          excel_mime_types = [
            'application/vnd.ms-excel',
            'application/msexcel',
            'application/x-msexcel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-excel.sheet.macroEnabled.12',
            'application/vnd.ms-excel.sheet.binary.macroEnabled.12'
          ]

          acceptable_types = csv_mime_types + excel_mime_types

          # Check if this is an acceptable file type
          is_acceptable_extension = %w[.csv .xls .xlsx].include?(file_ext)

          # Try to get content type safely, defaulting to a fallback if needed
          content_type = uploaded_file.content_type rescue nil
          content_type ||= case file_ext
                         when '.csv'
                           'text/csv'
                         when '.xls'
                           'application/vnd.ms-excel'
                         when '.xlsx'
                           'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                         else
                           'application/octet-stream'
                         end

          unless acceptable_types.include?(content_type) || is_acceptable_extension
            render json: {
              success: false,
              error: 'Invalid file format. Please upload a CSV or Excel file',
              details: {
                content_type: content_type,
                extension: file_ext
              }
            }, status: :unprocessable_entity
            return
          end

          # Create a temp file with a known encoding
          temp_file = Tempfile.new(['import', file_ext])
          begin
            # Read the file in binary mode to avoid encoding issues during read
            uploaded_io = uploaded_file.respond_to?(:tempfile) ? uploaded_file.tempfile : uploaded_file
            file_content = nil

            # Try to read the file safely
            begin
              file_content = File.binread(uploaded_io.path)
            rescue => e
              # If reading from path fails, try direct read method
              uploaded_io.rewind rescue nil
              file_content = uploaded_io.read rescue nil

              # If still failing, report error
              unless file_content
                raise "Could not read file content: #{e.message}"
              end
            end

            # Write content to temp file
            temp_file.binmode
            temp_file.write(file_content)
            temp_file.rewind

            # Create a custom class that extends Tempfile to handle file type detection
            temp_file.instance_eval do
              def original_filename
                # Return a sanitized filename with the right extension
                "import#{File.extname(path)}"
              end

              def content_type
                case File.extname(path).downcase
                when '.csv'
                  'text/csv'
                when '.xls'
                  'application/vnd.ms-excel'
                when '.xlsx'
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                else
                  'application/octet-stream'
                end
              end
            end            # Process the temp file
            result = TestCatalogService.import(temp_file)

            if result[:success]
              render json: result, status: :ok
            else
              render json: result, status: :unprocessable_entity
            end
          ensure
            # Always close and delete the temp file
            begin
              temp_file.close
              temp_file.unlink
            rescue => e
              Rails.logger.error("Error cleaning up temp file: #{e.message}")
            end
          end
        rescue ActionController::BadRequest => e
          # This is handled by the rescue_from at the class level
          raise e
        rescue => e
          # Log the full error with backtrace
          Rails.logger.error("Import error: #{e.message}\n#{e.backtrace.join("\n")}")

          # Return a user-friendly error message
          error_message = case e.message
                         when /invalid byte sequence/
                           "The file contains invalid characters. Please save it as UTF-8 encoded and try again."
                         when /premature end of data/
                           "The CSV file appears to be corrupt or improperly formatted. Please check the file format."
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
