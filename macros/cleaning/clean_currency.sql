{% macro clean_currency(column_name) %}

CAST(
    REGEXP_REPLACE({{ column_name }}, r'[$,]', '')
    AS NUMERIC
)

{% endmacro %}