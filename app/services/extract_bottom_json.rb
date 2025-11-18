class ExtractBottomJson
  class UnbalancedJsonError < StandardError; end
  class InvalidJsonError < StandardError; end

  def initialize
    @stack = []
  end

  def call(text)
    i = text.length - 1
    i -= 1 while i >= 0 && !["}", "]"].include?(text[i])

    return nil if i.negative?

    closing_char = text[i]
    opening_char = closing_char == "}" ? "{" : "["
    stack.push(opening_char)
    end_idx = i + 1
    i -= 1
    while i >= 0 && !stack.empty?
      char = text[i]
      if char == '"'
        i -= 1
        while i >= 0 && text[i] != '"'
          i -= 1 if text[i] == "\\"
          i -= 1
        end
        i -= 1 # skip opening quote
        next
      end
      if ["}", "]"].include?(char)
        expected_open = char == "}" ? "{" : "["
        stack.push(expected_open)
      elsif ["{", "["].include?(char)
        if stack.empty? || char != stack.pop
          return nil # mismatched
        end
      end
      i -= 1
    end
    return nil unless stack.empty?

    start_idx = i + 1

    text[start_idx...end_idx].strip

    if stack.empty?
      JSON.parse(text[start_idx...end_idx].strip)
    else
      raise UnbalancedJsonError, "Unbalanced JSON structure"
    end
  end

private

  attr_reader :stack
end
