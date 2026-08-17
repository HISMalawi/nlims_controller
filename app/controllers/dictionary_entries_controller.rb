# frozen_string_literal: true

# Changing the dictionary. The national node only: there is one dictionary in
# the country and one place it is written, and a local node that could edit its
# replica would produce codes nobody else has ever heard of.
#
# Every change here is signed. There are no released versions to approve, so the
# promotion is the approval, and it always records who made it.
class DictionaryEntriesController < ApplicationController
  before_action :require_admin
  before_action :set_model
  before_action :set_entry, except: %i[new create promote]

  def new
    @entry = @model.new
  end

  def create
    @entry = @model.new(entry_params)

    return render :new, status: :unprocessable_content unless @entry.save

    redirect_to dictionary_entity_path(@entity_type),
                notice: t(".created", code: @entry.national_code, name: @entry.name)
  end

  def edit; end

  def update
    return render :edit, status: :unprocessable_content unless @entry.update(entry_params)

    redirect_to dictionary_entity_path(@entity_type), notice: t(".updated", code: @entry.national_code)
  end

  # Publication. Until this happens the entry exists only here; afterwards it
  # travels down the delta to every laboratory in the country.
  def activate
    @entry.activate!(actor: current_user.to_actor, reason: params[:reason].presence)

    redirect_back fallback_location: dictionary_entity_path(@entity_type),
                  notice: t(".activated", code: @entry.national_code)
  end

  # Never a delete. A local node holding the old copy has to be told it is gone,
  # and a delete leaves nothing to tell it with.
  def retire
    @entry.retire!(actor: current_user.to_actor, reason: params[:reason].presence)

    redirect_back fallback_location: dictionary_entity_path(@entity_type),
                  notice: t(".retired", code: @entry.national_code)
  end

  # Publishing a whole import at once, holding back the entries a laboratory
  # could not actually use — a test with no indicators reports nothing, and a
  # test with no specimen types cannot be collected.
  def promote
    promotion = Dictionary::Promotion.new(actor: current_user.to_actor, skip_blocked: true).call
    promoted = promotion.promoted.values.sum
    held_back = promotion.held_back.values.sum

    redirect_to dictionary_path, notice: t(".promoted", promoted: promoted, held_back: held_back)
  end

  private

  def set_model
    @entity_type = params[:entity_type]
    @model = Dictionary.model_for(@entity_type)

    raise ActiveRecord::RecordNotFound if @model.nil? && action_name != "promote"
  end

  def set_entry
    @entry = @model.find_by!(national_code: params[:national_code])
  end

  def entry_params
    params.require(:entry).permit(*Dictionary::Editable.attribute_names_for(@entity_type))
  end
end
