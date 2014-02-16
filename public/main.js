var defaults = ["1 pulse #ff0000", "2 pulse #7fff00", "3 pulse #00ffff", "2 flash",
                "1 pulse #ff5f00", "2 pulse #21ff00", "3 pulse #00a1ff", "2 flash #ff0000",
                "1 pulse #ffbf00", "2 pulse #00ff3f", "3 pulse #003fff", "2 flash #00ff00",
                "1 pulse #e1ff00", "2 pulse #00ff9d", "3 pulse #1d00ff", "2 flash #0000ff",
                "1 brightness", "2 brightness", "3 brightness", "all brightness",
                "2 flash", "2 flash", "2 flash", "2 flash",
                "2 flash", "2 flash", "2 flash", "2 flash",
                "2 flash", "2 flash", "2 flash", "2 flash", "2 flash",
                "2 flash", "2 flash", "2 flash", "2 flash", "2 flash",
                "2 flash", "2 flash", "2 flash", "2 flash", "2 flash",
                "2 flash", "2 flash", "2 flash", "2 flash", "2 flash",
                "2 flash", "2 flash", "2 flash", "2 flash", "2 flash"];

var regexes = [
               /^\s*(\d(?:,\d)*|all)\s+on\s*$/g,
               /^\s*(\d(?:,\d)*|all)\s+off\s*$/g,
               /^\s*(\d(?:,\d)*|all)\s+(red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}|(?:rand|random)(?:\(red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}\s+red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}\))?)\s*$/g,
               /^\s*(\d(?:,\d)*|all)\s+(pulse|flash)(?:\s+((red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}|(?:rand|random)(?:\(red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}\s+red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}\))?)))?\s*$/g,
               /^\s*(\d(?:,\d)*|all)\s+(h|s|b|H|S|B|hue|sat|bri|saturation|brightness)(?:\s+(\d+))?\s*$/g,
               /^\s*(\d(?:,\d)*|all)\s+strobe(?:\s+(\d+))?(?:\s+((red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}|(?:rand|random)(?:\(red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}\s+red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}\))?)))?\s*$/g]

function hexToRgb(hex) {
    var result = /^#?([a-fA-F\d]{2})([a-fA-F\d]{2})([a-fA-F\d]{2})$/i.exec(hex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : null;
}

function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
}

function parse_color(s) {
    var x = s.substr(s.length - 7);
    return hexToRgb(x)? x :
        (endsWith(s, "red") && "#ff0000") || (endsWith(s, "green") && "#00ff00" || (endsWith(s, "blue") && "#0000ff") || (endsWith(s, "yellow") && "#ffff00") || (endsWith(s, "pink") && "#ff69b4") || (endsWith(s, "violet") && "#9400d3")));
}

function validate(s) {
    actions = s.split(", ");
    for (i in actions) {
        var satisfied = false;
        for (j in regexes) {
            if (actions[i].match(regexes[j])) {
                satisfied = true;
                break;
            }
        }
        if (!satisfied) {
            return false;
        }
    }
    return true;
}

function changed(name, value) {
    var good = validate(value);
    $( "#" + name + "-color" ).css({
        'background-color':
            ((good && (color = parse_color(value)) && color) || 'transparent')
    });
    if (good) {
        $( "#" + name ).addClass('good').removeClass('bad');
    } else {
        $( "#" + name ).addClass('bad').removeClass('good');
    }
    var data = {name: name, value: value};
    $.ajax('/ajax/changemode', {type: 'POST', data: data});
}

function AppViewModel() {
    control_names = parse_names();
    for (var i in control_names) {
        eval(control_names[i] + " = ko.observable(\"" + defaults[i] + "\");");
        // console.log(control_names[i] + " = ko.observable(\"" + defaults[i] + "\");");
        eval(control_names[i] + ".subscribe(function(){changed(\"" + control_names[i] + "\"," + control_names[i] + "())});")
        changed(control_names[i], defaults[i]);
    }
}

var interpreter_open = false;

$(document).ready(function() {
    ko.applyBindings(new AppViewModel());
    $( "#tf-icon" ).click(function() {
        $.ajax('/ajax/setcontroller1', {type: 'POST'});
        $( "#nk-set" ).hide(0);
        $( "#tf-set" ).show(0);
        // exit_calibration_mode();
    });
    $( "#nk-icon" ).click(function() {
        $.ajax('/ajax/setcontroller2', {type: 'POST'});
        $( "#tf-set" ).hide(0);
        $( "#nk-set" ).show(0);
        // exit_calibration_mode();
    });
    // $( "#calibration-link" ).click(function() {
    //     calibration_mode = true;
    //     do_calibration_mode();
    //     $( "#tf-set" ).hide();
    //     $( "#nk-set" ).hide();
    // });
    $( "#interpreter-link" ).click(function() {
        if (interpreter_open) {
            $( "#interpreter" ).slideUp();
            $( "#headerwrap" ).animate({'padding-top': '24px'}, 'easeOutQuad');
            interpreter_open = false;
        } else {
            $( "#interpreter" ).slideDown();
            $( "#headerwrap" ).animate({'padding-top': 0}, 'easeOutQuad');
            interpreter_open = true;
        }
    });
    $( "#interpreter" ).slideUp(0);
    $( "#interpreter-input" ).keypress(function(e) {
        if (e.which == 13) {
            this.select();
            var val = $(this).val();
            var good = validate(val);
            var flash_color = good? "#37dd37" : "#dd3737";
            $( "#interpreter" ).animate({'background-color': flash_color}, 220, 'easeOutQuad')
                               .animate({'background-color': '#373737'}, 220, 'easeOutQuad');
            if (good) {
                $.ajax('/ajax/execute', {type: 'POST', data: {action: val}});
            }
        }
    });
    $( ".input-box input.form-control" ).keypress(function(e) {
        if (e.which == 13) {
            var val = $(this).val();
            var good = validate(val);
            var flash_color = good? "#00ff00" : "#ff0000";
            $(this).animate({'background-color': flash_color}, 220, 'easeOutQuad')
                   .animate({'background-color': '#ffffff'}, 220, 'easeOutQuad');
            if (good) {
                $.ajax('/ajax/execute', {type: 'POST', data: {action: val}});
            }
        }
    });


    // $( "#calibration" ).fadeTo(0, 0);
    // pollMidi();
})

// function pollMidi() {
//     var data = {available: available};
//     $.post('/ajax/midi', data, function(data) {
//         if (data["changed"]) {
//             available = data["available"];
//             if ($.inArray("M", available)) {
//                 $( "#tf-icon" ).show();
//             } else {
//                 $( "#tf-icon" ).hide();
//         console.log("changed: " + data["changed"] + " available: " + available);
//             }
//             if ($.inArray("K", available)) {
//                 $( "#nk-icon" ).show();
//             } else {
//                 $( "#nk-icon" ).hide();
//         console.log("changed: " + data["changed"] + " available: " + available);
//             }
//         }
//         setTimeout(pollMidi, 500);
//     });
// }

// var calibration_mode = false;

// function do_calibration_mode() {
//     $.post('/ajax/signal', {}, function(data) {
//         if (!calibration_mode) return;
//         if (data["signal"]) {
//             $( "#calibration" ).fadeTo(200, 1).fadeTo(200, 0);
//         }
//         do_calibration_mode();
//     });
// }

// function exit_calibration_mode() {
//     calibration_mode = false;
//     $.post('/ajax/signalstop');
//     $( "#calibration" ).fadeTo(0, 0);
// }