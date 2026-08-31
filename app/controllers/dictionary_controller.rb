# frozen_string_literal: true

# Reading the dictionary. Both modes: a local node holds a replica and its
# operators need to see what their laboratory can actually order, quite as much
# as the national node needs to see what it is publishing.
#
# Changing it is DictionaryEntriesController, and only on the national node.
class DictionaryController < ApplicationController
  PER_PAGE = 100

  def index
    @counts = Dictionary::ENTITIES.keys.index_with do |entity_type|
      model = Dictionary.model_for!(entity_type)
      { active: model.active.count, draft: model.drafts.count, retired: model.retired.count }
    end

    @cursor = Dictionary.cursor
    @local_cursor = SyncCursor.for(SyncCursor::DICTIONARY) if SislabSync.local?

    # The whole-dictionary figure, so the gap is visible on the way in rather
    # than only after picking an entity type.
    @loinc = Dictionary::LoincCoverage.new

    # The reason a promotion can be held back, and the list an administrator
    # works through before publishing. Only worth computing where entries can
    # actually be changed.
    @quality = Dictionary::QualityReport.new.rows.group_by(&:issue).transform_values(&:count) if SislabSync.national?
  end

  def show
    @entity_type = params[:entity_type]
    @model = Dictionary.model_for(@entity_type)

    raise ActiveRecord::RecordNotFound if @model.nil?

    @status = params[:status].presence_in(DictionaryEntry::STATUSES)
    @term = params[:q].to_s.strip

    @entries = scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @total = scope.count
    @page = page
    @pages = [ (@total / PER_PAGE.to_f).ceil, 1 ].max

    # How much of this entity type has a LOINC code. Stated because it is the
    # gap S11 exists to close, and a percentage is what makes it a task rather
    # than a vague intention — but only where a LOINC code means anything. A
    # laboratory section has no equivalent, and showing it as permanently 0%
    # would make the figure noise everywhere it does matter.
    @curated = Dictionary::Loinc.curated?(@entity_type)

    if @curated
      @with_loinc = @model.active.where.not(loinc_code: nil).count
      @active_total = @model.active.count
    end
  end

  private

  def scope
    relation = @model.order(:name)
    relation = relation.where(status: @status) if @status
    return relation if @term.blank?

    like = "#{ActiveRecord::Base.sanitize_sql_like(@term)}%"
    relation.where("name LIKE :like OR national_code = :exact OR moh_code = :exact OR loinc_code = :exact",
                   like: like, exact: @term.upcase)
  end

  def page
    [ params[:page].to_i, 1 ].max
  end
end
