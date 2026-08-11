{% macro normalize_hull_id(column_name) %}

UPPER(REGEXP_REPLACE({{ column_name }}, r'[^a-zA-Z0-9]', ''))

{% endmacro %}