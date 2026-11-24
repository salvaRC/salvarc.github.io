module Jekyll
  module HideCustomBibtex
    # Cleans the BibTeX shown in the "BibTeX" box of each publication:
    #   1. removes website-only fields listed in `filtered_bibtex_keywords` (_config.yml).
    #      Only lines whose *field name* matches are removed, so e.g. a `url` containing
    #      "arxiv" or a title containing "code" are kept.
    #   2. removes the "*" equal-contribution markers from author names.
    def hideCustomBibtex(input)
      keywords = @context.registers[:site].config['filtered_bibtex_keywords'] || []

      keywords.each do |keyword|
        input = input.gsub(/^\s*#{Regexp.escape(keyword)}\s*=.*$\n?/i, '')
      end

      input = input.gsub(/^(\s*author\s*=.*)$/i) { |line| line.gsub('*', '') }

      return input
    end
  end
end

Liquid::Template.register_filter(Jekyll::HideCustomBibtex)
