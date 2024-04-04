post_person:
	curl -vvv -X POST http://localhost:8888/persons -H "Content-Type: application/json" -d '{"name": "Anton", "surname": "Romanov", "age": 38}'

get_person:
	curl -v -X GET http://localhost:8888/persons/1

ver:
	curl -v -X GET http://localhost:8888/version
