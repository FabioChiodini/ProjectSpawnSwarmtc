from flask import Flask, request, jsonify
from pprint import pprint
import json

app = Flask(__name__)


@app.route('/log', methods=['POST'])
def log():
    try:
        data_to_log = json.loads(request.json)
        pprint(data_to_log)
    except Exception as e:
        print(e)
        raise(e)
    return(jsonify({'result':'ok'}))


if __name__ == '__main__':
    app.run(host="0.0.0.0",port=61116, debug=True)
