load("http.star", "http")
load("render.star", "render")
load("time.star", "time")

# Entur API endpoint for real-time departures
ENTUR_API_URL = "https://api.entur.io/journey-planner/v3/graphql"
DISPLAY_WIDTH = 64
DISPLAY_HEIGHT = 32
HEADER_HEIGHT = 6
SEPARATOR_HEIGHT = 1
ROW_HEIGHT = 8
MAX_VISIBLE_ROWS = (DISPLAY_HEIGHT - HEADER_HEIGHT - SEPARATOR_HEIGHT) // ROW_HEIGHT

def truncate_text(text, max_len):
    if not text:
        return ""
    if len(text) <= max_len:
        return text
    if max_len <= 1:
        return text[:max_len]
    return text[:max_len - 1] + "…"

def abbreviate_stop_words(text):
    if not text:
        return ""

    words = text.split(" ")
    short_words = []

    for word in words:
        lower_word = word.lower()
        if lower_word != "gate" and lower_word != "vei" and lower_word != "veg":
            short_words.append(word)

    return " ".join(short_words)

def display_stop_name(name):
    return truncate_text(abbreviate_stop_words(name), 14)

def minutes_until_departure(current_time, departure_time):
    # Extract HH:MM from ISO format strings
    current_hours = int(current_time[11:13])
    current_minutes = int(current_time[14:16])
    departure_hours = int(departure_time[11:13])
    departure_minutes = int(departure_time[14:16])

    # Convert to total minutes
    current_total = current_hours * 60 + current_minutes
    departure_total = departure_hours * 60 + departure_minutes

    # Calculate difference
    minutes_until = departure_total - current_total

    # Handle next day case
    if minutes_until < 0:
        minutes_until = minutes_until + (24 * 60)

    return minutes_until

def departure_time_style(minutes_left):
    if minutes_left <= 1:
        return ("NOW", "#ff6b6b")
    if minutes_left <= 5:
        return (str(minutes_left) + "m", "#a95200ff")
    return (str(minutes_left) + "m", "#519de9ff")

def live_indicator():
    return render.Box(
        width = 6,
        height = HEADER_HEIGHT,
        child = render.Animation(
            children = [
                render.Circle(diameter = 2, color = "#2f9e4418"),
                render.Circle(diameter = 2, color = "#2f9e4470"),
                render.Circle(diameter = 3, color = "#2f9e44b0"),
                render.Circle(diameter = 2, color = "#2f9e4470"),
            ],
        ),
    )

def header_box(stop_name, text_color):
    return render.Box(
        width = DISPLAY_WIDTH,
        height = HEADER_HEIGHT,
        child = render.Stack(
            children = [
                render.Box(
                    width = DISPLAY_WIDTH,
                    height = HEADER_HEIGHT,
                    child = render.Text(
                        content = display_stop_name(stop_name),
                        font = "CG-pixel-4x5-mono",
                        color = text_color,
                    ),
                ),
                render.Box(
                    width = DISPLAY_WIDTH,
                    height = HEADER_HEIGHT,
                    child = render.Row(
                        expanded = True,
                        main_align = "end",
                        cross_align = "center",
                        children = [
                            live_indicator(),
                        ],
                    ),
                ),
            ],
        ),
    )

def main(config):
    # Get stop IDs from config (with temporary preview defaults)
    stop_id = config.get("stop_id", "NSR:StopPlace:6286")
    quay_id = config.get("quay_id", "NSR:Quay:11544")
    stop_name = config.get("stop_name", "")
    requested_departures = int(config.get("num_departures", 3))
    if requested_departures < 1:
        requested_departures = 1
    if requested_departures > 5:
        requested_departures = 5
    num_departures = requested_departures

    # GraphQL query for departures
    query = """{
      stopPlace(id: "%s") {
        name
        quays {
          id
          estimatedCalls(timeRange: 72000, numberOfDepartures: %d) {
                        expectedDepartureTime
            serviceJourney {
              line {
                publicCode
              }
            }
          }
        }
      }
    }""" % (stop_id, num_departures)

    # Set up headers
    headers = {
        "ET-Client-Name": "entur-tidbyt-display",
        "Content-Type": "application/json",
    }

    # Make the request to Entur API
    rep = http.post(
        ENTUR_API_URL,
        json_body = {"query": query},
        headers = headers,
    )

    if rep.status_code != 200:
        return render.Root(
            delay = 350,
            child = render.Column(
                children = [
                    header_box(stop_name or "Bus Stop", "#b0b0b0"),
                    render.Text(
                        "No live data",
                        font = "CG-pixel-4x5-mono",
                        color = "#ff6b6b",
                    ),
                    render.Text(
                        "Try again soon",
                        font = "CG-pixel-4x5-mono",
                        color = "#6c757d",
                    ),
                ],
            ),
        )

    # Parse the JSON response
    response_data = rep.json()
    departures = []
    header = header_box(stop_name or "Bus Stop", "#b0b0b0")
    separator = render.Box(
        width = DISPLAY_WIDTH,
        height = SEPARATOR_HEIGHT,
        color = "#a7d6ebff",
    )

    # Extract departure information
    if "data" in response_data and "stopPlace" in response_data["data"]:
        stop_place = response_data["data"]["stopPlace"]
        if not stop_name:
            stop_name = stop_place.get("name", "Unknown Stop")

        # Create the header box
        header = header_box(stop_name, "#62cfebff")

        if "quays" in stop_place:
            for quay in stop_place["quays"]:
                if quay["id"] == quay_id and "estimatedCalls" in quay:
                    for call in quay["estimatedCalls"]:
                        if len(departures) >= MAX_VISIBLE_ROWS:
                            break

                        line = call["serviceJourney"]["line"]["publicCode"]
                        departure_time = call["expectedDepartureTime"]

                        # Get current time in the same format as departure_time
                        current_time = time.now().format("2006-01-02T15:04:05-07:00")
                        minutes_left = minutes_until_departure(current_time, departure_time)
                        time_str, time_color = departure_time_style(minutes_left)

                        departures.append(
                            render.Box(
                                width = DISPLAY_WIDTH,
                                height = ROW_HEIGHT,
                                child = render.Row(
                                    main_align = "space_between",
                                    children = [
                                        render.Box(
                                            width = 26,
                                            child = render.Text(
                                                content = truncate_text(line, 6),
                                                font = "CG-pixel-4x5-mono",
                                                color = "#ffd166",
                                            ),
                                        ),
                                        render.Box(
                                            width = 24,
                                            child = render.Text(
                                                content = time_str,
                                                font = "CG-pixel-4x5-mono",
                                                color = time_color,
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                        )

                    break
    else:
        print("No stop place data found")

    if not departures:
        departures = [
            render.Text(
                "No departures",
                font = "CG-pixel-4x5-mono",
                color = "#ced4da",
            ),
        ]

    return render.Root(
        delay = 350,
        child = render.Column(
            children = [header, separator] + departures,
        ),
    )
