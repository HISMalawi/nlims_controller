# frozen_string_literal: true

# Turning the contract into a page.
#
# The descriptions in docs/sislab-sync/openapi.yaml are written for whoever is
# reading them — in a generator, in an editor, or here — so they carry the small
# amount of Markdown that costs nothing to read raw: paragraphs, bullets, code
# spans, emphasis, fenced blocks. This renders that much and no more, rather
# than pulling in a Markdown library to serve one page.
module ApiDocsHelper
  VERB_STYLES = {
    "GET" => "bg-sky-100 text-sky-800 ring-sky-600/20",
    "POST" => "bg-emerald-100 text-emerald-800 ring-emerald-600/20",
    "PATCH" => "bg-amber-100 text-amber-800 ring-amber-600/20",
    "PUT" => "bg-amber-100 text-amber-800 ring-amber-600/20",
    "DELETE" => "bg-rose-100 text-rose-800 ring-rose-600/20"
  }.freeze

  def contract_verb_class(verb)
    VERB_STYLES.fetch(verb, "bg-slate-100 text-slate-700 ring-slate-600/20")
  end

  # A 2xx is what the caller came for; everything else is what they need when it
  # goes wrong, which is a different question and reads better apart.
  def contract_success?(status)
    status.to_s.start_with?("2")
  end

  def contract_status_class(status)
    contract_success?(status) ? "text-emerald-700" : "text-slate-500"
  end

  def contract_prose(text)
    return if text.blank?

    safe_join(prose_blocks(text.to_s))
  end

  # "string ou nulo", "array de Order", "integer" — what the reader needs to
  # know about a field, without making them open the schema to find out.
  def contract_type(schema)
    schema = ApiContract.expand(schema)
    types = Array(schema["type"]).map { |type| t("api_docs.types.#{type}", default: type) }
    label = types.compact_blank.to_sentence(two_words_connector: " ou ", last_word_connector: " ou ")

    return label if label.present?
    return t("api_docs.types.enum") if schema["enum"]

    t("api_docs.types.any")
  end

  def contract_enum(schema)
    ApiContract.expand(schema)["enum"]
  end

  private

  def prose_blocks(text)
    blocks(text).map do |block|
      case block
      when /\A```/ then tag.pre(block.gsub(/\A```\w*\n?|\n?```\z/, ""), class: "contract-pre")
      when /\A## / then tag.h4(inline(block.delete_prefix("## ")), class: "contract-h4")
      when /\A[-*] /
        tag.ul(class: "contract-list") do
          safe_join(block.lines.map { |line| tag.li(inline(line.strip.sub(/\A[-*] /, ""))) })
        end
      else tag.p(inline(block), class: "contract-p")
      end
    end
  end

  # Fenced blocks keep their blank lines; everything else splits on them. The
  # capture is what keeps the fences in the result rather than discarding them.
  def blocks(text)
    text.split(/(```.*?```)/m).flat_map do |part|
      part.start_with?("```") ? [ part ] : part.split(/\n{2,}/)
    end.map(&:strip).compact_blank
  end

  def inline(text)
    escaped = ERB::Util.html_escape(text.strip.gsub(/\s*\n\s*/, " "))
    escaped = escaped.gsub(/`([^`]+)`/) { tag.code(Regexp.last_match(1).html_safe, class: "contract-code") }

    escaped.gsub(/\*\*([^*]+)\*\*/) { tag.strong(Regexp.last_match(1).html_safe) }.html_safe
  end
end
