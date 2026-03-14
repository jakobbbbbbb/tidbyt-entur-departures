# Norway Transport

A Tidbyt app that displays real-time public transport departures from any stop in Norway using the Entur API.

## Features

- Shows real-time departures from your selected bus/train stop
- Displays line numbers and departure times
- Configurable number of departures to show (1-5)
- Updates in real-time
- Shows "Nå" when the bus is due to depart within the next minute
- Stop name is fetched automatically if not provided

## Configuration

To use this app, configure the following settings in your Tidbyt:

1. `stop_id` (required): The Entur stop ID (e.g., "NSR:StopPlace:6286" for Colletts gate in Oslo)
2. `quay_id` (required): The specific quay/platform ID at your stop (e.g., "NSR:Quay:11544")
3. `stop_name` (optional): Custom display name for your stop. If left blank, the app will use the name from the Entur API.
4. `num_departures` (optional): Number of departures to display (1-5, default: 3)

### Finding Your Stop IDs

You can find the `stop_id` and `quay_id` for any stop in Norway by:

1. Visiting [Entur's website](https://entur.no) or [Entur's API explorer](https://api.entur.io/graphql-explorer)
2. Searching for your stop
3. Inspecting the stop details to get the NSR IDs

## Installation

1. Install the app on your Tidbyt from the Tidbyt app store or by uploading the `.star` file.
2. Configure the settings as described above.
3. Enjoy real-time departures!

## Support

For support or to report issues, please visit the [GitHub repository](https://github.com/jakobbbbbbb/entur-departures-no).
