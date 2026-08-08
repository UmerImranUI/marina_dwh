{% macro clean_currency(column_name) %}

ROUND(
    CAST(
        REGEXP_REPLACE({{ column_name }}, r'[$,]', '')
        AS NUMERIC
    ),
    2
)

{% endmacro %}