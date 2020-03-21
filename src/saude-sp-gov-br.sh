#!/bin/bash
set -e
set -o errexit
set -o nounset
set -o pipefail
cd "$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

source "fetch_cached.sh"

which pdftohtml
which sed
which awk
which tr

function get_nearby_value() {
    awk -F $'\t' '
        BEGIN { d = "0" }
        { y = $1; x = $2 }
        NR==1 { d_x = x; d_y = y }
        NR>1 && x > d_x && y < d_y+20 && y > d_y-20 && $3 ~ /[0-9]+/{
            d = $3
            exit 0
        }
        END{ print d }
        ' "$@"
}

function parse_pdf() {
    local pdf_file="$(fetch_once "${1}")"

    local text_blocks="$(
        pdftohtml -q -i -stdout -xml "${pdf_file}" |
            awk '/^<text/' |
            sed 's%<b>%%g' |
            sed 's%</b>%%g' |
            sed -r 's%<text top="([^"]*)" left="([^"]*)[^>]*>(.*)<\/text>%\1\t\2\t\3%g' |
            sort -n
    )"

    local date="$(
        echo "${text_blocks}" |
            tr '[:upper:]' '[:lower:]' |
            awk -F $'\t' '$3 ~ /[0-9]+ de .* de 20[0-9]{2}/ {print $3; exit}' |
            awk '{
                m["janeiro"]="01";
                m["fevereiro"]="02";
                m["março"]="03";
                m["abril"]="04";
                m["maio"]="05";
                m["junho"]="06";
                m["julho"]="07";
                m["agosto"]="08";
                m["setembro"]="09";
                m["outubro"]="10";
                m["novembro"]="11";
                m["dezembro"]="12";
                print $5 "-" m[$3] "-" $1 
            }'
    )"

    local deaths_text="$(echo "${text_blocks}" | awk -F $'\t' '$3~/Óbitos/')"
    local deaths="$(get_nearby_value <(echo "${deaths_text}") <(echo "${text_blocks}"))"

    local cases_text="$(echo "${text_blocks}" | awk -F $'\t' '$3~/^Casos Confirmados/')"
    local cases="$(get_nearby_value <(echo "${cases_text}") <(echo "${text_blocks}"))"

    echo -e "${date}\t${deaths}\t${cases}\t${1}"
}

INDEX_URL="http://www.saude.sp.gov.br/cve-centro-de-vigilancia-epidemiologica-prof.-alexandre-vranjac/areas-de-vigilancia/doencas-de-transmissao-respiratoria/coronavirus-covid-19/situacao-epidemiologica"
OUTPUT_DIR="$(realpath ../output)"
SCRIPT_NAME="$(basename "${0}")"
OUTPUT_FILE_PREFIX="${OUTPUT_DIR}/${SCRIPT_NAME%.*}"

if [[ ! -f "${OUTPUT_FILE_PREFIX}-$(date '+%Y-%m-%d').tsv" ]]; then
    mkdir -p "${OUTPUT_DIR}"
    PDF_FILES="$(
        cat "$(fetch_daily "${INDEX_URL}")" |
            sed 's[http://www.saude.sp.gov.br/resources[/resources[g' |
            tr '"' '\n' |
            awk '!/alerta/ && /\/res/ && /\.pdf$/ && !o[$0]++ {print "http://www.saude.sp.gov.br" $1}'
    )"

    while read url; do
        fetch_once "${url}" &
    done <<<"${PDF_FILES}"
    wait < <(jobs -p)

    (
        echo -e "date\tdeaths\tcases\tpdf_url"
        while read url; do
            parse_pdf "${url}"
        done <<<"${PDF_FILES}"
    ) >"${OUTPUT_FILE_PREFIX}-latest.tsv"

    cp "${OUTPUT_FILE_PREFIX}-latest.tsv" "${OUTPUT_FILE_PREFIX}-$(date '+%Y-%m-%d').tsv"
fi

cat "${OUTPUT_FILE_PREFIX}-latest.tsv"
