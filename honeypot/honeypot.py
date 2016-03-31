from flask import Flask, jsonify, request
import os
import requests
from pprint import pprint
import json

if 'LOG_HOST' not in os.environ or 'LOG_PORT' not in os.environ:
    raise(Exception("LOG_HOST OR LOG_PORT NOT DEFINED"))

POST_URL = "http://{host}:{port}/log".format(host=os.environ['LOG_HOST'],port=os.environ['LOG_PORT'])

app = Flask(__name__)

def log_request(req):
    data_to_log = {}
    data_to_log.update(req.headers)
    ip = request.environ.get('X-Forwarded-For', request.remote_addr)
    data_to_log.update({"ip": ip})
    data_to_log.update({"url": req.full_path})
    try:
        requests.post(POST_URL,json=json.dumps(data_to_log))
    except Exception as e:
        print(e)


@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def honey(path):
    log_request(request)
    return jsonify({'result': 'ok'})


if __name__ == '__main__':
    app.run(host="0.0.0.0",port=8080)
