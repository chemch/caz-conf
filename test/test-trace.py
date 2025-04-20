from flask import Flask
from jaeger_client import Config
import logging
import time

# Set up logging
logging.getLogger('').handlers = []
logging.basicConfig(format='%(message)s', level=logging.DEBUG)

# Set up Jaeger Tracer
def init_tracer(service_name='my-sample-app'):
    config = Config(
        config={
            'sampler': {'type': 'const', 'param': 1},
            'logging': True,
            'local_agent': {
                'reporting_host': 'jaeger-agent.tracing.svc.cluster.local',
                'reporting_port': 6831,
            }
        },
        service_name=service_name,
    )
    return config.initialize_tracer()

app = Flask(__name__)
tracer = init_tracer()

@app.route('/trace')
def trace():
    with tracer.start_span('sample-trace') as span:
        span.log_kv({'event': 'doing some work'})
        time.sleep(1)
        span.log_kv({'event': 'done'})
    return "Trace sent!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000)