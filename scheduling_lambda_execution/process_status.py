

def handler(event, context):
    print("status event::", event)
    print("status context::", context)

    all_stopped = True

    animal_name= event["animal_name"]
    consider_variable = event["consider"]
    terrestrial = event["terrestrial"]

    event.update({"all_stopped": all_stopped})
    return event
