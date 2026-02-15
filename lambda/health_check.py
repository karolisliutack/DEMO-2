"""
Health Check Lambda Function

This Lambda function handles health check requests from API Gateway,
validates incoming payloads, logs to CloudWatch, and stores request
details in DynamoDB.
"""

import json
import logging
import os
import uuid
from datetime import datetime
from typing import Any, Dict

import boto3
from botocore.exceptions import ClientError

# Configure CloudWatch logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')


def get_table():
    """
    Get DynamoDB table from environment variable.

    Returns:
        DynamoDB Table resource

    Raises:
        ValueError: If DYNAMODB_TABLE environment variable is not set
    """
    table_name = os.environ.get('DYNAMODB_TABLE')
    if not table_name:
        raise ValueError("DYNAMODB_TABLE environment variable not set")
    return dynamodb.Table(table_name)


def validate_post_payload(body: Dict[str, Any]) -> tuple[bool, str]:
    """
    Validate that the request body contains required 'payload' key.

    Args:
        body: Parsed JSON body from request

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not isinstance(body, dict):
        return False, "Request body must be a JSON object"

    if 'payload' not in body:
        return False, "Missing required field: 'payload'"

    return True, ""


def save_to_dynamodb(table, request_data: Dict[str, Any]) -> str:
    """
    Save request details to DynamoDB.

    Args:
        table: DynamoDB table resource
        request_data: Request data to save

    Returns:
        Generated UUID for the record

    Raises:
        ClientError: If DynamoDB write fails
    """
    record_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()

    item = {
        'id': record_id,
        'timestamp': timestamp,
        'http_method': request_data.get('http_method', 'UNKNOWN'),
        'source_ip': request_data.get('source_ip', 'unknown'),
        'user_agent': request_data.get('user_agent', 'unknown'),
        'payload': request_data.get('payload', {}),
        'ttl': int(datetime.utcnow().timestamp()) + (90 * 24 * 60 * 60)  # 90 days TTL
    }

    table.put_item(Item=item)
    logger.info(f"Successfully saved record with ID: {record_id}")

    return record_id


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create API Gateway proxy integration response.

    Args:
        status_code: HTTP status code
        body: Response body dictionary

    Returns:
        API Gateway formatted response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body)
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for health check API.

    Handles both GET and POST requests:
    - GET: Returns healthy status without requiring payload
    - POST: Validates payload, logs request, saves to DynamoDB

    Args:
        event: API Gateway proxy integration event
        context: Lambda context object

    Returns:
        API Gateway proxy integration response
    """
    # Log the incoming event for debugging
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Get DynamoDB table
        table = get_table()

        # Extract HTTP method
        http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method', 'UNKNOWN'))
        logger.info(f"HTTP Method: {http_method}")

        # Extract source IP and user agent
        request_context = event.get('requestContext', {})
        source_ip = request_context.get('identity', {}).get('sourceIp',
                    request_context.get('http', {}).get('sourceIp', 'unknown'))
        user_agent = event.get('headers', {}).get('User-Agent',
                     event.get('headers', {}).get('user-agent', 'unknown'))

        # Handle GET requests
        if http_method == 'GET':
            logger.info("Processing GET request - returning healthy status without validation")

            # Still log to DynamoDB for monitoring
            request_data = {
                'http_method': http_method,
                'source_ip': source_ip,
                'user_agent': user_agent,
                'payload': {'type': 'health_check', 'method': 'GET'}
            }

            record_id = save_to_dynamodb(table, request_data)

            return create_response(200, {
                'status': 'healthy',
                'message': 'Health check passed',
                'record_id': record_id,
                'timestamp': datetime.utcnow().isoformat()
            })

        # Handle POST requests
        elif http_method == 'POST':
            # Parse request body
            body_str = event.get('body', '{}')

            # Handle base64 encoded body if present
            if event.get('isBase64Encoded', False):
                import base64
                body_str = base64.b64decode(body_str).decode('utf-8')

            try:
                body = json.loads(body_str) if body_str else {}
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in request body: {e}")
                return create_response(400, {
                    'error': 'Invalid JSON',
                    'message': 'Request body must be valid JSON'
                })

            # Validate payload
            is_valid, error_message = validate_post_payload(body)
            if not is_valid:
                logger.warning(f"Payload validation failed: {error_message}")
                return create_response(400, {
                    'error': 'Validation Error',
                    'message': error_message
                })

            # Save to DynamoDB
            request_data = {
                'http_method': http_method,
                'source_ip': source_ip,
                'user_agent': user_agent,
                'payload': body.get('payload')
            }

            record_id = save_to_dynamodb(table, request_data)

            return create_response(200, {
                'status': 'healthy',
                'message': 'Request processed and saved',
                'record_id': record_id,
                'timestamp': datetime.utcnow().isoformat()
            })

        # Handle OPTIONS (CORS preflight)
        elif http_method == 'OPTIONS':
            return create_response(200, {'message': 'OK'})

        # Unsupported method
        else:
            logger.warning(f"Unsupported HTTP method: {http_method}")
            return create_response(405, {
                'error': 'Method Not Allowed',
                'message': f'HTTP method {http_method} is not supported. Use GET or POST.'
            })

    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        return create_response(500, {
            'error': 'Configuration Error',
            'message': str(e)
        })

    except ClientError as e:
        logger.error(f"DynamoDB error: {e}")
        return create_response(500, {
            'error': 'Database Error',
            'message': 'Failed to save request data'
        })

    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return create_response(500, {
            'error': 'Internal Server Error',
            'message': 'An unexpected error occurred'
        })
