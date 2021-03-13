import flask

app = flask.Flask(__name__)

@app.route('/api/health')
def health():
    print('Processing: \'' + flask.request.url + '\'', flush=True)
    return flask.jsonify({"success": True})

@app.route('/home')
def home():
    return flask.jsonify("Welcome to the application")


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)