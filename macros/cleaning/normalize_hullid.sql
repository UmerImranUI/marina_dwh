{% macro normalize_hull_id(column_name) %}

UPPER(
    REGEXP_REPLACE(
        TRIM({{ column_name }}),
        r'[^A-Za-z0-9]',
        ''
    )
)

{% endmacro %}