/**
 * Unit Tests for ApiConfig, ApiEndpoints, ApiHeaders, and HttpStatus
 */

import { describe, it, expect } from '@ohos/hypium';
import { ApiConfig, ApiEndpoints, ApiHeaders, HttpStatus } from '../../../../main/ets/data/api/ApiConfig';

export default function ApiConfigTest() {
  describe('ApiConfig', () => {
    describe('BASE_URL', () => {
      it('should have correct base URL', () => {
        expect(ApiConfig.BASE_URL).assertEqual('https://reqres.in/api');
      });

      it('should be a valid HTTPS URL', () => {
        expect(ApiConfig.BASE_URL.startsWith('https://')).assertTrue();
      });
    });

    describe('API_KEY', () => {
      it('should have an API key defined', () => {
        expect(ApiConfig.API_KEY).assertNotNull();
        expect(ApiConfig.API_KEY.length > 0).assertTrue();
      });

      it('should be a reqres API key', () => {
        expect(ApiConfig.API_KEY.startsWith('reqres_')).assertTrue();
      });
    });

    describe('TIMEOUT', () => {
      it('should have a reasonable timeout value', () => {
        expect(ApiConfig.TIMEOUT).assertEqual(30000);
      });

      it('should be greater than zero', () => {
        expect(ApiConfig.TIMEOUT > 0).assertTrue();
      });
    });

    describe('PAGE_SIZE', () => {
      it('should have default page size of 6', () => {
        expect(ApiConfig.PAGE_SIZE).assertEqual(6);
      });

      it('should be a positive number', () => {
        expect(ApiConfig.PAGE_SIZE > 0).assertTrue();
      });
    });

    describe('MAX_RETRIES', () => {
      it('should have max retries of 3', () => {
        expect(ApiConfig.MAX_RETRIES).assertEqual(3);
      });

      it('should be at least 1', () => {
        expect(ApiConfig.MAX_RETRIES >= 1).assertTrue();
      });
    });

    describe('RETRY_DELAY', () => {
      it('should have retry delay of 1000ms', () => {
        expect(ApiConfig.RETRY_DELAY).assertEqual(1000);
      });

      it('should be a positive number', () => {
        expect(ApiConfig.RETRY_DELAY > 0).assertTrue();
      });
    });

    describe('CACHE_TTL', () => {
      it('should have cache TTL of 5 minutes', () => {
        expect(ApiConfig.CACHE_TTL).assertEqual(5 * 60 * 1000);
      });

      it('should be a positive number', () => {
        expect(ApiConfig.CACHE_TTL > 0).assertTrue();
      });
    });
  });

  describe('ApiEndpoints', () => {
    describe('USERS', () => {
      it('should have correct users endpoint', () => {
        expect(ApiEndpoints.USERS).assertEqual('/users');
      });

      it('should start with forward slash', () => {
        expect(ApiEndpoints.USERS.startsWith('/')).assertTrue();
      });
    });

    describe('userById', () => {
      it('should return correct endpoint for user ID 1', () => {
        expect(ApiEndpoints.userById(1)).assertEqual('/users/1');
      });

      it('should return correct endpoint for user ID 123', () => {
        expect(ApiEndpoints.userById(123)).assertEqual('/users/123');
      });

      it('should return correct endpoint for user ID 0', () => {
        expect(ApiEndpoints.userById(0)).assertEqual('/users/0');
      });

      it('should return correct endpoint for large user ID', () => {
        expect(ApiEndpoints.userById(999999)).assertEqual('/users/999999');
      });

      it('should start with forward slash', () => {
        expect(ApiEndpoints.userById(42).startsWith('/')).assertTrue();
      });
    });
  });

  describe('ApiHeaders', () => {
    describe('CONTENT_TYPE', () => {
      it('should be application/json', () => {
        expect(ApiHeaders.CONTENT_TYPE).assertEqual('application/json');
      });
    });

    describe('ACCEPT', () => {
      it('should be application/json', () => {
        expect(ApiHeaders.ACCEPT).assertEqual('application/json');
      });
    });

    describe('API_KEY_HEADER', () => {
      it('should be x-api-key', () => {
        expect(ApiHeaders.API_KEY_HEADER).assertEqual('x-api-key');
      });

      it('should be lowercase', () => {
        expect(ApiHeaders.API_KEY_HEADER).assertEqual(ApiHeaders.API_KEY_HEADER.toLowerCase());
      });
    });
  });

  describe('HttpStatus', () => {
    describe('Success codes', () => {
      it('should have OK as 200', () => {
        expect(HttpStatus.OK).assertEqual(200);
      });

      it('should have CREATED as 201', () => {
        expect(HttpStatus.CREATED).assertEqual(201);
      });

      it('should have NO_CONTENT as 204', () => {
        expect(HttpStatus.NO_CONTENT).assertEqual(204);
      });
    });

    describe('Client error codes', () => {
      it('should have BAD_REQUEST as 400', () => {
        expect(HttpStatus.BAD_REQUEST).assertEqual(400);
      });

      it('should have UNAUTHORIZED as 401', () => {
        expect(HttpStatus.UNAUTHORIZED).assertEqual(401);
      });

      it('should have FORBIDDEN as 403', () => {
        expect(HttpStatus.FORBIDDEN).assertEqual(403);
      });

      it('should have NOT_FOUND as 404', () => {
        expect(HttpStatus.NOT_FOUND).assertEqual(404);
      });

      it('should have CONFLICT as 409', () => {
        expect(HttpStatus.CONFLICT).assertEqual(409);
      });

      it('should have UNPROCESSABLE_ENTITY as 422', () => {
        expect(HttpStatus.UNPROCESSABLE_ENTITY).assertEqual(422);
      });

      it('should have TOO_MANY_REQUESTS as 429', () => {
        expect(HttpStatus.TOO_MANY_REQUESTS).assertEqual(429);
      });
    });

    describe('Server error codes', () => {
      it('should have INTERNAL_SERVER_ERROR as 500', () => {
        expect(HttpStatus.INTERNAL_SERVER_ERROR).assertEqual(500);
      });

      it('should have BAD_GATEWAY as 502', () => {
        expect(HttpStatus.BAD_GATEWAY).assertEqual(502);
      });

      it('should have SERVICE_UNAVAILABLE as 503', () => {
        expect(HttpStatus.SERVICE_UNAVAILABLE).assertEqual(503);
      });

      it('should have GATEWAY_TIMEOUT as 504', () => {
        expect(HttpStatus.GATEWAY_TIMEOUT).assertEqual(504);
      });
    });

    describe('Status code ranges', () => {
      it('should have all success codes in 2xx range', () => {
        expect(HttpStatus.OK >= 200 && HttpStatus.OK < 300).assertTrue();
        expect(HttpStatus.CREATED >= 200 && HttpStatus.CREATED < 300).assertTrue();
        expect(HttpStatus.NO_CONTENT >= 200 && HttpStatus.NO_CONTENT < 300).assertTrue();
      });

      it('should have all client error codes in 4xx range', () => {
        expect(HttpStatus.BAD_REQUEST >= 400 && HttpStatus.BAD_REQUEST < 500).assertTrue();
        expect(HttpStatus.UNAUTHORIZED >= 400 && HttpStatus.UNAUTHORIZED < 500).assertTrue();
        expect(HttpStatus.FORBIDDEN >= 400 && HttpStatus.FORBIDDEN < 500).assertTrue();
        expect(HttpStatus.NOT_FOUND >= 400 && HttpStatus.NOT_FOUND < 500).assertTrue();
        expect(HttpStatus.TOO_MANY_REQUESTS >= 400 && HttpStatus.TOO_MANY_REQUESTS < 500).assertTrue();
      });

      it('should have all server error codes in 5xx range', () => {
        expect(HttpStatus.INTERNAL_SERVER_ERROR >= 500 && HttpStatus.INTERNAL_SERVER_ERROR < 600).assertTrue();
        expect(HttpStatus.BAD_GATEWAY >= 500 && HttpStatus.BAD_GATEWAY < 600).assertTrue();
        expect(HttpStatus.SERVICE_UNAVAILABLE >= 500 && HttpStatus.SERVICE_UNAVAILABLE < 600).assertTrue();
        expect(HttpStatus.GATEWAY_TIMEOUT >= 500 && HttpStatus.GATEWAY_TIMEOUT < 600).assertTrue();
      });
    });
  });
}
