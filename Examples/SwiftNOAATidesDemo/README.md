# Tides & Currents example

Open `SwiftNOAATidesDemo.xcodeproj`, select the generated app scheme and an iOS 26 or newer
simulator, then run. Close the standalone package workspace first so Xcode resolves one package copy.
Like the NWS, NPS Data, and GovInfo demos, this app uses a local `../..` package reference and the
service's SDK and models products.

Choose a station from the NOAA tide-prediction directory, select a day in GMT, and load predicted
high and low tides. The app requests meters above MLLW and displays the provider's event order.
Subordinate stations remain selectable; provider refusals are shown without substituting stations.
No API key is required. Launching the app fetches the directory; predictions load only on request.

These are predictions, not measured water levels. The app does not calculate extrema, interpolate
heights, convert datums, or provide navigation advice.
