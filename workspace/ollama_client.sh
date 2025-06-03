#!/bin/bash

SERVER_PID=""
# Check if Ollama server is not running and start it
if ! pgrep -f "ollama serve" >/dev/null; then
    # Start Ollama server
    ollama serve >/dev/null 2>&1 &
    SERVER_PID=$!
    
    # Wait for connection
    timeout=60
    while ! nc -z localhost 11434 && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
    done
    
    # Quit if connection fails
    if ! nc -z localhost 11434; then
        echo "Error: Unable to reach Ollama server"
        exit 1
    fi
    echo "Ollama server startup (PID: $SERVER_PID)"
fi

# Colors and formatting (ANSI/VT100)
# Format text
RESET='\033[0m'
BOLD='\033[1m'
# Foreground colors
WHITE='\033[0;97m'
# Background colors
BG_DARK_GRAY='\033[48;5;235m'
# All the way down the line
FILL_LINE='\e[K'


# Colorize code blocks
colorize_md() {
    local in_code_block=false

    color_markdown_line() {
        local line="$1"
        
        # Markdown start
        if [[ "$line" =~ ^\`\`\` ]]; then
            if [ "$in_code_block" = false ]; then
                in_code_block=true
                
            else
                in_code_block=false   
            fi

            echo -e "${BOLD}$line${RESET}\n"
            return
        fi

        # Code block
        if [ "$in_code_block" = true ]; then
            local full_line=""
            
            # Stream chunks
            while IFS= read -r chunk; do
                if [[ -z "$chunk" ]]; then
                    # Color full line of code (padding)
                    if [[ ! -z "$full_line" ]]; then
                        echo -e "${WHITE}${BG_DARK_GRAY}${BOLD}"
                        echo "$full_line"
                        echo -e "${FILL_LINE}${RESET}\n"
                        
                        full_line=""
                    fi
                        
                else
                    # Markdown stop
                    if [[ "$chunk" =~ ^\`\`\` || "$chunk" == "\`\`\`" ]]; then
                        in_code_block=false
                        
                        echo -e "${BOLD}$chunk${RESET}"
                        # Return to normal colors
                        break
                        
                     else
                        # Construct line with chunks to prepare padding
                        full_line="$full_line$chunk"
                    fi
                fi
            done

        # Text block
        else
            echo "$line"
        fi
    }
    
    # Color processing
    while IFS= read -r line || [[ -n "$line" ]]; do
        color_markdown_line "$line"
    done
}    
export -f colorize_md    

# SIGINT
function on_sigint() {
    if [ -n "$SERVER_PID" ] && kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "\nOllama server shutdown (PID: $SERVER_PID)"
        kill $SERVER_PID
        wait $SERVER_PID 2>/dev/null
    fi
    exit 0
}
export -f on_sigint

# Catch SIGINT
trap on_sigint SIGINT

# History
add_history() {
  local role=$1 content=$2
  jq --arg role "$role" --arg content "$content" \
     '. += [ { role: $role, content: $content } ]' \
     /tmp/ollama_history.json > /tmp/ollama_history.tmp && \
  mv /tmp/ollama_history.tmp /tmp/ollama_history.json
}
export -f add_history

# Build payload to request API
build_payload() {
    jq -n \
        --arg model "$MODEL" \
        --slurpfile messages /tmp/ollama_history.json \
        --argjson stream true \
        --argjson temperature "$TEMPERATURE" \
        --argjson top_p "$TOP_P" \
        '{ messages: $messages[0],
           model: $model,
           stream: $stream,
           temperature: $temperature,
           top_p: $top_p }' \
        > "$REQUEST_PAYLOAD_FILE"
    # Debug
    #cat "$REQUEST_PAYLOAD_FILE"
}
export -f build_payload



# Choose model (default: codellama)
MODEL="${1:-codellama:13b-instruct}"

TEMPERATURE=0.3
TOP_P=0.7
REQUEST_PAYLOAD_FILE=/tmp/ollama_request.json

# User name
USER_NAME=$(whoami)
USER_NAME="${USER_NAME^^}"

# Info
echo
echo "  Local manager: Ollama"
echo "  Model: $MODEL"
echo "  Default model: codellama:13b-instruct"
echo "  Usage: $0 <model>"
echo "  Type 'exit' to quit."

# Model name
#MODEL="${MODEL^^}"

# Ollama API entry
API_URL="http://localhost:11434/api/chat"

# Prepare history to keep the context in mind
echo '[]' > /tmp/ollama_history.json
# US version
INIT_HISTORY="You are an excellent free software developer. You write high-quality code. You aim to provide people with professional and accurate information. Your task is to assist the user in creating code."
# French version
#INIT_HISTORY="Vous êtes un excellent développeur de logiciels libres. Vous écrivez du code de haute qualité. Votre objectif est de fournir aux gens des informations professionnelles et précises. Votre tâche consiste à aider l'utilisateur à créer du code."
add_history system "$INIT_HISTORY"

# Main loop
while true; do
    # User input
    #printf "\n\e[1;32m$USER_NAME:\e[0m "
    printf "\n\e[1;32mYou:\e[0m "
    echo
    read -r -e -p "" USER_INPUT
    [[ "$USER_INPUT" == "exit" || "$USER_INPUT" == "quit" ]] && on_sigint #&& break

    # Add prompt to history
    add_history user "$USER_INPUT"
    
    # Build context
    build_payload

    printf "\n\e[1;34m$MODEL:\e[0m \n"

    # Prepare to extract message
    chunked=""
    
    # Request API
    stdbuf -oL curl -sN -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d @"$REQUEST_PAYLOAD_FILE" \
    | stdbuf -oL jq -R -r 'select(length>=0)             
            | fromjson?                  
            | .message.content // empty' \
    | tee >(
        # Raw capture (without color) for history
        {
            raw_response=$(cat)
            
            # Cleaning before sending
            clean_response=$(printf '%s' "$raw_response" | sed ':a;N;$!ba; s/\r//g; s/\n\n\n\n\n/..nnnnn../g; s/\n\n\n/..nnn../g; s/..nnnnn../\n\n/g; s/\n//g; s/..nnnnn../\n\n/g; s/..nnn../\n/g; s/..nn../\n/g')

            # Add answer to history
            add_history assistant "$clean_response"
        }
    ) \
    > >(
            # process-substitution : feed that FIFO to the 'while' of the current shell
            # Colorize code blocks
            colorize_md \
            | \
            while IFS= read -r chunk; do
                if [[ -z "$chunk" ]]; then
                    if [[ ! -z "$chunked" ]]; then
                        printf "\n"
                        # Prepare to extract new message
                        chunked=""
                    fi
                else
                    # Stream API answer
                    printf "%s" "$chunk"
                    chunked="$chunked$chunk"
                fi
            done
    )
done
