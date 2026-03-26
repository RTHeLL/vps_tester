#!/bin/bash

# ============================================
# VPS/VDS Professional Testing Script
# Version: 1.0
# Author: VPS Testing Suite
# ============================================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
TOTAL_SCORE=0
MAX_SCORE=100
FAILED_TESTS=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE="${SCRIPT_DIR}/vps_test_results_$(date +%Y%m%d_%H%M%S).md"

# Hashtags system
HASHTAGS=(
    "#VPS_TEST" "#VDS_TEST" "#SERVER_REVIEW"
    "#HOSTING_REVIEW" "#BENCHMARK" "#PERFORMANCE_TEST"
)

# Initialize result file
init_result_file() {
    cat > "$RESULT_FILE" << EOF
# VPS/VDS Тестирование - $(date +"%Y-%m-%d %H:%M:%S")

## Общая информация
| Параметр | Значение |
|----------|---------|
| Дата тестирования | $(date +"%Y-%m-%d %H:%M:%S") |
| Хост | $(hostname) |
| Тестировщик | $(whoami) |
| Система | $(uname -a) |

## Результаты тестов

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $1" >> "${RESULT_FILE%.md}_log.txt"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[SUCCESS] $1" >> "${RESULT_FILE%.md}_log.txt"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "${RESULT_FILE%.md}_log.txt"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "${RESULT_FILE%.md}_log.txt"
}

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1"
    echo "[TEST] $1" >> "${RESULT_FILE%.md}_log.txt"
}

# Function to calculate score
calculate_score() {
    local score=$1
    local max=$2
    echo "scale=1; ($score * 10) / $max" | bc
}

# Function to add test result
add_test_result() {
    local test_name="$1"
    local test_status="$2"  # PASS, FAIL, SKIP
    local test_score="$3"
    local test_details="$4"
    local skip_reason="${5:-}"
    
    if [[ "$test_status" == "PASS" ]]; then
        TOTAL_SCORE=$((TOTAL_SCORE + test_score))
        echo -e "${GREEN}✓${NC} $test_name: +${test_score} баллов"
        echo "| $test_name | ✅ **ПРОЙДЕН** | $test_score/10 | $test_details |" >> "$RESULT_FILE"
    elif [[ "$test_status" == "FAIL" ]]; then
        FAILED_TESTS+=("$test_name")
        echo -e "${RED}✗${NC} $test_name: 0 баллов - $test_details"
        echo "| $test_name | ❌ **НЕ ПРОЙДЕН** | 0/10 | $test_details |" >> "$RESULT_FILE"
    else
        echo -e "${YELLOW}⊘${NC} $test_name: Пропущен - $skip_reason"
        echo "| $test_name | ⚠️ **ПРОПУЩЕН** | 0/10 | $skip_reason |" >> "$RESULT_FILE"
    fi
}

# Test 1: IP Region
test_ip_region() {
    log_test "Тест 1: Определение региона IP"
    
    local temp_file="/tmp/ip_region_test.txt"
    
    if bash <(wget -qO- https://ipregion.vrnt.xyz) > "$temp_file" 2>&1; then
        local ip_info=$(cat "$temp_file")
        log_success "IP регион определен"
        
        # Extract country from output
        local country=$(echo "$ip_info" | grep -i "country" | head -1 || echo "Unknown")
        local city=$(echo "$ip_info" | grep -i "city" | head -1 || echo "Unknown")
        
        add_test_result "IP Region" "PASS" 10 "Страна: $country, Город: $city"
        echo -e "${CYAN}IP Информация:${NC}\n$ip_info"
    else
        log_error "Не удалось определить регион IP"
        add_test_result "IP Region" "FAIL" 0 "Ошибка выполнения скрипта или недоступность сервиса"
    fi
    
    rm -f "$temp_file"
}

# Test 2: Geoblock Check
test_geoblock() {
    log_test "Тест 2: Проверка геоблокировок"
    
    local temp_file="/tmp/geoblock_test.txt"
    
    if bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode geoblock > "$temp_file" 2>&1; then
        local geoblock_result=$(cat "$temp_file")
        
        if echo "$geoblock_result" | grep -qi "blocked\|geoblock"; then
            log_warning "Обнаружены геоблокировки"
            add_test_result "Censorcheck (Geoblock)" "PASS" 10 "Обнаружены ограничения: $(echo "$geoblock_result" | grep -i "blocked" | head -1)"
        else
            log_success "Геоблокировки не обнаружены"
            add_test_result "Censorcheck (Geoblock)" "PASS" 10 "Сервер доступен без геоблокировок"
        fi
        
        echo -e "${CYAN}Результат проверки:${NC}\n$geoblock_result"
    else
        log_error "Не удалось выполнить проверку геоблокировок"
        add_test_result "Censorcheck (Geoblock)" "FAIL" 0 "Ошибка выполнения скрипта"
    fi
    
    rm -f "$temp_file"
}

# Test 3: DPI Check (For Russian Servers)
test_dpi() {
    log_test "Тест 3: Проверка DPI (для РФ серверов)"
    
    local temp_file="/tmp/dpi_test.txt"
    local server_location=$(curl -s ifconfig.co/country 2>/dev/null || echo "Unknown")
    
    if [[ "$server_location" == "RU" ]] || [[ "$server_location" == "Russia" ]]; then
        log_info "Сервер находится в РФ, выполняем проверку DPI"
        
        if bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi > "$temp_file" 2>&1; then
            local dpi_result=$(cat "$temp_file")
            
            if echo "$dpi_result" | grep -qi "dpi\|deep packet"; then
                log_warning "Обнаружены признаки DPI"
                add_test_result "Censorcheck (DPI)" "PASS" 10 "Обнаружены признаки Deep Packet Inspection"
            else
                log_success "DPI не обнаружен"
                add_test_result "Censorcheck (DPI)" "PASS" 10 "Система DPI не обнаружена"
            fi
            
            echo -e "${CYAN}Результат DPI проверки:${NC}\n$dpi_result"
        else
            log_error "Не удалось выполнить проверку DPI"
            add_test_result "Censorcheck (DPI)" "FAIL" 0 "Ошибка выполнения скрипта"
        fi
    else
        log_info "Сервер находится вне РФ ($server_location), проверка DPI не требуется"
        add_test_result "Censorcheck (DPI)" "SKIP" 0 "Пропущено" "Сервер находится вне РФ"
    fi
    
    rm -f "$temp_file"
}

# Test 4: Russian iPerf3 Servers
test_iperf_russia() {
    log_test "Тест 4: Тест скорости до российских iPerf3 серверов"
    
    local temp_file="/tmp/iperf_test.txt"
    
    if bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh) > "$temp_file" 2>&1; then
        log_success "Тест iPerf3 выполнен"
        
        # Extract bandwidth information
        local bandwidth=$(grep -i "bits/sec\|Mbits/sec" "$temp_file" | tail -1 || echo "Not available")
        
        add_test_result "Russian iPerf3 Test" "PASS" 10 "Скорость: $bandwidth"
        echo -e "${CYAN}Результаты iPerf3 теста:${NC}\n$(tail -20 "$temp_file")"
    else
        log_error "Не удалось выполнить тест iPerf3"
        add_test_result "Russian iPerf3 Test" "FAIL" 0 "Ошибка выполнения теста"
    fi
    
    rm -f "$temp_file"
}

# Test 5: YABS (Yet Another Bench Script)
test_yabs() {
    log_test "Тест 5: YABS - полное бенчмарк тестирование"
    
    local temp_file="/tmp/yabs_test.txt"
    
    log_info "Выполняется YABS тест (может занять 3-5 минут)..."
    
    if curl -sL yabs.sh | bash -s -- -4 > "$temp_file" 2>&1; then
        log_success "YABS тест выполнен"
        
        # Extract key metrics
        local cpu_model=$(grep "CPU Model" "$temp_file" | head -1 || echo "Not available")
        local disk_speed=$(grep "dd" "$temp_file" | head -1 || echo "Not available")
        local geekbench=$(grep "Geekbench" "$temp_file" | head -1 || echo "Not available")
        
        add_test_result "YABS Benchmark" "PASS" 10 "CPU: $cpu_model, Disk: $disk_speed"
        echo -e "${CYAN}Ключевые результаты YABS:${NC}\n$cpu_model\n$disk_speed\n$geekbench"
        
        # Save full results
        echo -e "\n## Полные результаты YABS\n\`\`\`\n$(cat "$temp_file")\n\`\`\`" >> "$RESULT_FILE"
    else
        log_error "Не удалось выполнить YABS тест"
        add_test_result "YABS Benchmark" "FAIL" 0 "Ошибка выполнения теста"
    fi
    
    rm -f "$temp_file"
}

# Function to display summary
display_summary() {
    local final_score=$(calculate_score $TOTAL_SCORE $MAX_SCORE)
    
    echo -e "\n${PURPLE}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📊 ИТОГОВЫЙ ОТЧЕТ ТЕСТИРОВАНИЯ${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
    echo -e "Общий балл: ${GREEN}$TOTAL_SCORE${NC} из ${MAX_SCORE}"
    echo -e "Итоговая оценка: ${YELLOW}$final_score/10${NC}"
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo -e "\n${RED}❌ Невыполненные тесты:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  • $test"
        done
    fi
    
    echo -e "\n${GREEN}✅ Хештеги для отчета:${NC}"
    for hashtag in "${HASHTAGS[@]}"; do
        echo -n "$hashtag "
    done
    echo -e "\n"
    
    # Add summary to result file
    cat >> "$RESULT_FILE" << EOF

## Итоговый отчет

| Показатель | Значение |
|-----------|---------|
| **Общий балл** | **$TOTAL_SCORE / $MAX_SCORE** |
| **Итоговая оценка** | **$final_score/10** |
| **Невыполненные тесты** | ${#FAILED_TESTS[@]} |

### Хештеги
\`\`\`
${HASHTAGS[@]}
\`\`\`

---
*Отчет сгенерирован автоматически $(date +"%Y-%m-%d %H:%M:%S")*
EOF
    
    echo -e "${GREEN}📄 Полный отчет сохранен в: $RESULT_FILE${NC}"
}

# Function to check dependencies
check_dependencies() {
    local deps=("wget" "curl" "bc")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Отсутствуют зависимости: ${missing_deps[*]}"
        log_info "Установка зависимостей..."
        
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${missing_deps[@]}"
        else
            log_error "Не удалось установить зависимости. Установите вручную: ${missing_deps[*]}"
            exit 1
        fi
    fi
}

# Main function
main() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     VPS/VDS Professional Testing Suite v1.0          ║"
    echo "║     Автоматическое тестирование серверов             ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_warning "Скрипт запущен от root. Рекомендуется запуск от обычного пользователя"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Initialize result file
    init_result_file
    
    # Run tests
    test_ip_region
    echo ""
    test_geoblock
    echo ""
    test_dpi
    echo ""
    test_iperf_russia
    echo ""
    test_yabs
    echo ""
    
    # Display summary
    display_summary
    
    # Exit with appropriate code
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
