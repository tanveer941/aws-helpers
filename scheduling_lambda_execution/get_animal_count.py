

def handler(event, context):
    print("count event::", event)
    print("count context::", context)

    animal_info = event["animal_info"]
    number_of_animals = animal_info["count"]
    if number_of_animals > 500:
        process = True
    else:
        process = False

    return {"animal_name": animal_info["name"],
            "consider": process,
            "terrestrial": animal_info["type"]}