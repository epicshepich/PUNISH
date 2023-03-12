using Dash

app = dash()

app.layout = html_div()

run_server(app, "0.0.0.0", 8248, debug=true)
