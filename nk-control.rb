class NKControl

    NOTE_TYPE = 144

    MIN_NOTE = 48
    MAX_NOTE = 72

    MAX_VALUE = 127

    attr_reader :kind, :id, :value, :percentage

    def initialize(type, id, value)
        case type

            when NOTE_TYPE
                @kind = "key"
                @id = id - MIN_NOTE
                @value = value
                @percentage = @value / MAX_VALUE.to_f

        end
    end
end
