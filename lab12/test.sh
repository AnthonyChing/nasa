#!/bin/bash
uri="http://localhost:11434/api/chat"
model="llama3.2" # Change this to the model name you use.

message='[]' # Initialize messages as an empty JSON array
tools='[{"type": "function","function": {"name": "monitor","description": "The api endpoint to get the cpu loads of the workstaions of NTU CSIE.","parameters": {"type": "object"}},"url": "https://monitor.csie.ntu.edu.tw/api/machines"}]'
while true; do
  # Prompt the user for input
  echo -ne "\033[1;32mEnter your prompt (type 'exit' to quit): \033[0m"
  read user_input

  if [ "$user_input" == "exit" ]; then
    echo "Bye!"
    # curl -X POST "$uri/generate" -H "Content-Type: application/json" -d "{\"model\": \"$model\", \"keep_alive\": 0}" # Unload the model
    break
  fi

  message=$(echo "$message" | jq '. += [{"role": "user", "content": $input}]' --arg input "$user_input")
  # Add the user prompt to messages

  endcall=false
  while [ "$endcall" == "false" ]; do # Continue until there are no tool calls
	body=$(jq -n --argjson messages "$message" --argjson tools "$tools" '{model: $model, messages: $messages, tools: $tools, stream: false}' --arg model "$model")
    response=$(curl -s -X POST "$uri" -H "Content-Type: application/json" -d "$body")
    
    assistant_message=$(echo "$response" | jq .message)
    message=$(echo "$message" | jq '. += [$input]' --argjson input "$assistant_message")

    endcall=true

    tool_calls=$(echo "$response" | jq -r '.message.tool_calls // []')
    if [ "$tool_calls" != "[]" ]; then
      num_calls=$(echo "$tool_calls" | jq length)
      for ((i=0; i<num_calls; i++)); do
        tool_name=$(echo "$tool_calls" | jq -r ".[$i].function.name")
        tool_input=$(echo "$tool_calls" | jq -r ".[$i].function.arguments")

        if [ "$tool_name" == "monitor" ]; then
          command_return=$(curl -s "$(echo "$tools" | jq -r '.[0].url')")
          parsed_output=$(echo "$command_return" | jq -r '.message | to_entries | map("\(.key) cpu load: \(.value.cpu.text)") | .[]')
          message=$(echo "$message" | jq '. += [{"role": "tool", "content": $input}]' --arg input "$parsed_output") # Add tool return to messages
          endcall=false # POST again to return command output
        fi
      done
    fi

    content=$(echo "$assistant_message" | jq -r '.content // ""') # If message is present, print to the user.
    if [ -n "$content" ]; then
      echo "$content"
    fi
  done
done