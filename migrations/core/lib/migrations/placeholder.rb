# frozen_string_literal: true

require "securerandom"

module Migrations
  # Single source of truth for the opaque tokens that stand in for deferred post
  # embeds (uploads, polls, events, quotes, links, mentions) inside `post.raw`.
  #
  # An embed cannot always be finalized while a post is converted: rendering it
  # needs the `original_id -> discourse_id` maps that only exist at import time.
  # The converter therefore splices a *placeholder* token into the raw and records
  # a typed linkage row carrying the same token; the importer rewrites the token
  # once the maps are available (see `Migrations::Importer::PlaceholderResolver`).
  #
  # The contract that makes this safe is a single invariant: the token spliced into
  # `raw` and the `placeholder` stored on the linkage row are byte-identical. Because
  # this class owns the token grammar, substitution at import time is a plain `gsub`
  # — no whitespace-padding hacks, no per-post SQL.
  #
  # ## Token format
  #
  # A token is bracketed by a Unicode Private Use Area delimiter (`U+E000`) and
  # carries a per-run random nonce:
  #
  #     <nonce>.<kind>.<sequence>
  #
  # Two independent guarantees keep a token from ever colliding with user content:
  #
  #   1. **Delimiter** — `U+E000` is a private-use code point with no assigned
  #      meaning; it does not occur in real post content, so a bare `gsub` of the
  #      whole token is unambiguous and the v1 link whitespace-padding hack is
  #      unnecessary.
  #   2. **Nonce** — a random value generated once per `Placeholder` instance (i.e.
  #      once per conversion run). Even if a delimiter somehow leaked into source
  #      text, the token still could not be forged because the nonce is
  #      unpredictable.
  #
  # The `kind` and `sequence` segments are not required for correctness —
  # uniqueness comes from the nonce plus the monotonic sequence — but they keep
  # tokens readable when inspecting a raw body while debugging.
  class Placeholder
    # Private Use Area code point used to bracket every token.
    DELIMITER = "\u{E000}"

    # Matches a whole token regardless of which run minted it (the nonce is opaque
    # here). Used by the importer and tests to find every token in a raw body.
    PATTERN = /#{DELIMITER}[^#{DELIMITER}]+#{DELIMITER}/

    # @param nonce [String] overridable only so tests can mint deterministic
    #   tokens; production code should let it default to a random value.
    def initialize(nonce: SecureRandom.alphanumeric(16))
      @nonce = nonce
      @sequence = 0
    end

    # Mints the next unique token for the given embed `kind` (e.g. `:quote`).
    #
    # @param kind [Symbol, String]
    # @return [String] the token to splice into `raw` and store as `placeholder`.
    def mint(kind)
      @sequence += 1
      "#{DELIMITER}#{@nonce}.#{kind}.#{@sequence}#{DELIMITER}"
    end

    # @return [Array<String>] every token present in `text`, in order of appearance.
    def self.scan(text)
      text.to_s.scan(PATTERN)
    end

    # @return [Boolean] whether `text` still contains at least one token.
    def self.include?(text)
      PATTERN.match?(text.to_s)
    end
  end
end
