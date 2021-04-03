

def handler(event, context):
    print("event::", event)
    print("context::", context)
    all_stopped = False
    event['all_stopped'] = all_stopped
    return True







