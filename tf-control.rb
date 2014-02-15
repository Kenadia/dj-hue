=begin
The M-Audio Trigger Finger has 16 buttons, 4 sliders, and 8 knobs.
We interpret the signals sent by Trigger Finger in its default setting.
    This means that the buttons send note data while the sliders and knobs
    send control data.
The id field represents the index of the control within its grouping,
    i.e. a TFControl with kind=KIND_KNOB has an id from 0 to 7.
=end

class TFControl

    KIND_BUTTON = 0
    KIND_SLIDER = 1
    KIND_KNOB = 2

    NOTE_TYPE = 153
    CONTROL_TYPE = 185

    BUTTON_NOTES = [[36, 127], [38, 127], [42, 127], [49, 127],
                    [36, 100], [38, 100], [46, 127], [51, 127],
                    [36, 80], [38, 80], [42, 64], [51, 64],
                    [36, 64], [38, 64], [46, 64], [49, 64]]
    SLIDER_NOTES = [7, 1, 71, 74]
    KNOB_NOTES = [10, 12, 5, 84, 91, 93, 71, 72]

    MAX_VALUE = 127

    attr_reader :kind, :id, :value, :percentage

    def initialize(type, id, value)
        case type

            when NOTE_TYPE
                self.kind = KIND_BUTTON
                self.id = BUTTON_NOTES.index([id, value])
                
            when CONTROL_TYPE
                self.id = SLIDER_NOTES.index(id)
                if self.id
                    self.kind = KIND_SLIDER
                else
                    self.kind = KIND_KNOB
                    self.id = KNOB_NOTES.index(id)
                end
                self.value = value
                self.percentage = self.value / MAX_VALUE.to_f

        end
    end
end
