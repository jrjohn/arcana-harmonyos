/**
 * Unit Tests for Navigation and Deep Linking
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  Routes,
  RouteType,
  UserListRoute,
  UserDetailRoute,
  CreateUserRoute,
  EditUserRoute
} from '../../../main/ets/core/navigation/Routes';
import { DeepLinkRouter, UriQueryParser } from '../../../main/ets/core/navigation/DeepLinkRouter';
import { MockLogger } from '../../../main/ets/core/di/testing';

export default function NavigationTest() {
  describe('Routes', () => {
    describe('Route Factories', () => {
      it('should create UserList route', () => {
        const route = Routes.userList();

        expect(route.type).assertEqual('UserList');
        expect((route as UserListRoute).params).toBeUndefined();
      });

      it('should create UserDetail route with userId', () => {
        const route = Routes.userDetail(123);

        expect(route.type).assertEqual('UserDetail');
        expect((route as UserDetailRoute).params.userId).assertEqual(123);
      });

      it('should create CreateUser route', () => {
        const route = Routes.createUser();

        expect(route.type).assertEqual('CreateUser');
      });

      it('should create EditUser route with userId', () => {
        const route = Routes.editUser(456);

        expect(route.type).assertEqual('EditUser');
        expect((route as EditUserRoute).params.userId).assertEqual(456);
      });
    });

    describe('Type Guards', () => {
      it('should correctly identify UserList route', () => {
        const route = Routes.userList();
        expect(Routes.isUserList(route)).assertTrue();
        expect(Routes.isUserDetail(route)).assertFalse();
      });

      it('should correctly identify UserDetail route', () => {
        const route = Routes.userDetail(1);
        expect(Routes.isUserDetail(route)).assertTrue();
        expect(Routes.isUserList(route)).assertFalse();
      });

      it('should correctly identify CreateUser route', () => {
        const route = Routes.createUser();
        expect(Routes.isCreateUser(route)).assertTrue();
        expect(Routes.isEditUser(route)).assertFalse();
      });

      it('should correctly identify EditUser route', () => {
        const route = Routes.editUser(1);
        expect(Routes.isEditUser(route)).assertTrue();
        expect(Routes.isCreateUser(route)).assertFalse();
      });
    });

    describe('getTitle', () => {
      it('should return correct title for UserList', () => {
        const route = Routes.userList();
        expect(Routes.getTitle(route)).assertEqual('Users');
      });

      it('should return correct title for UserDetail', () => {
        const route = Routes.userDetail(1);
        expect(Routes.getTitle(route)).assertEqual('User Detail');
      });

      it('should return correct title for CreateUser', () => {
        const route = Routes.createUser();
        expect(Routes.getTitle(route)).assertEqual('Create User');
      });

      it('should return correct title for EditUser', () => {
        const route = Routes.editUser(1);
        expect(Routes.getTitle(route)).assertEqual('Edit User');
      });
    });

    describe('getPath', () => {
      it('should return correct path for UserList', () => {
        const route = Routes.userList();
        expect(Routes.getPath(route)).assertEqual('/users');
      });

      it('should return correct path for UserDetail', () => {
        const route = Routes.userDetail(42);
        expect(Routes.getPath(route)).assertEqual('/users/42');
      });

      it('should return correct path for CreateUser', () => {
        const route = Routes.createUser();
        expect(Routes.getPath(route)).assertEqual('/users/new');
      });

      it('should return correct path for EditUser', () => {
        const route = Routes.editUser(99);
        expect(Routes.getPath(route)).assertEqual('/users/99/edit');
      });
    });
  });

  describe('DeepLinkRouter', () => {
    let router: DeepLinkRouter;
    let mockLogger: MockLogger;

    beforeEach(() => {
      mockLogger = new MockLogger();
      router = new DeepLinkRouter();
      router.setLogger(mockLogger);
    });

    describe('handleUri', () => {
      it('should handle arcana://app/users', async () => {
        const result = await router.handleUri('arcana://app/users');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserList');
      });

      it('should handle arcana://app/home', async () => {
        const result = await router.handleUri('arcana://app/home');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserList');
      });

      it('should handle arcana://app/users/123', async () => {
        const result = await router.handleUri('arcana://app/users/123');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserDetail');
        expect((result.route as UserDetailRoute).params.userId).assertEqual(123);
      });

      it('should handle arcana://app/user/456', async () => {
        const result = await router.handleUri('arcana://app/user/456');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserDetail');
        expect((result.route as UserDetailRoute).params.userId).assertEqual(456);
      });

      it('should handle arcana://app/users/new', async () => {
        const result = await router.handleUri('arcana://app/users/new');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('CreateUser');
      });

      it('should handle arcana://app/user/create', async () => {
        const result = await router.handleUri('arcana://app/user/create');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('CreateUser');
      });

      it('should handle arcana://app/users/123/edit', async () => {
        const result = await router.handleUri('arcana://app/users/123/edit');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('EditUser');
        expect((result.route as EditUserRoute).params.userId).assertEqual(123);
      });

      it('should handle https://arcana.app/users/789', async () => {
        const result = await router.handleUri('https://arcana.app/users/789');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserDetail');
        expect((result.route as UserDetailRoute).params.userId).assertEqual(789);
      });

      it('should return not handled for unknown URI', async () => {
        const result = await router.handleUri('arcana://app/unknown/path');

        expect(result.handled).assertFalse();
        expect(result.error).not.toBeUndefined();
      });

      it('should normalize trailing slashes', async () => {
        const result = await router.handleUri('arcana://app/users/');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserList');
      });

      it('should be case insensitive for scheme and host', async () => {
        const result = await router.handleUri('ARCANA://APP/users');

        expect(result.handled).assertTrue();
        expect(result.route?.type).assertEqual('UserList');
      });
    });

    describe('canHandle', () => {
      it('should return true for valid URIs', () => {
        expect(router.canHandle('arcana://app/users')).assertTrue();
        expect(router.canHandle('arcana://app/users/123')).assertTrue();
        expect(router.canHandle('arcana://app/users/new')).assertTrue();
      });

      it('should return false for invalid URIs', () => {
        expect(router.canHandle('arcana://app/invalid')).assertFalse();
        expect(router.canHandle('https://other.com/users')).assertFalse();
      });
    });

    describe('subscribe', () => {
      it('should notify subscribers on URI handling', async () => {
        let notifiedResult: any;
        const unsubscribe = router.subscribe((result) => {
          notifiedResult = result;
        });

        await router.handleUri('arcana://app/users');

        expect(notifiedResult).not.toBeUndefined();
        expect(notifiedResult.handled).assertTrue();

        unsubscribe();
      });

      it('should allow unsubscribe', async () => {
        let callCount = 0;
        const unsubscribe = router.subscribe(() => {
          callCount++;
        });

        await router.handleUri('arcana://app/users');
        expect(callCount).assertEqual(1);

        unsubscribe();

        await router.handleUri('arcana://app/users');
        expect(callCount).assertEqual(1);
      });
    });

    describe('buildUri', () => {
      it('should build URI for UserList', () => {
        const route = Routes.userList();
        const uri = DeepLinkRouter.buildUri(route);

        expect(uri).assertEqual('arcana://app/users');
      });

      it('should build URI for UserDetail', () => {
        const route = Routes.userDetail(123);
        const uri = DeepLinkRouter.buildUri(route);

        expect(uri).assertEqual('arcana://app/users/123');
      });

      it('should build URI for CreateUser', () => {
        const route = Routes.createUser();
        const uri = DeepLinkRouter.buildUri(route);

        expect(uri).assertEqual('arcana://app/users/new');
      });

      it('should build URI for EditUser', () => {
        const route = Routes.editUser(456);
        const uri = DeepLinkRouter.buildUri(route);

        expect(uri).assertEqual('arcana://app/users/456/edit');
      });
    });

    describe('buildWebUrl', () => {
      it('should build web URL for UserList', () => {
        const route = Routes.userList();
        const url = DeepLinkRouter.buildWebUrl(route);

        expect(url).assertEqual('https://arcana.app/users');
      });

      it('should build web URL for UserDetail', () => {
        const route = Routes.userDetail(123);
        const url = DeepLinkRouter.buildWebUrl(route);

        expect(url).assertEqual('https://arcana.app/users/123');
      });
    });
  });

  describe('UriQueryParser', () => {
    describe('parse', () => {
      it('should parse query parameters', () => {
        const params = UriQueryParser.parse('https://example.com?foo=bar&baz=qux');

        expect(params['foo']).assertEqual('bar');
        expect(params['baz']).assertEqual('qux');
      });

      it('should handle URL encoded values', () => {
        const params = UriQueryParser.parse('https://example.com?name=John%20Doe&email=test%40example.com');

        expect(params['name']).assertEqual('John Doe');
        expect(params['email']).assertEqual('test@example.com');
      });

      it('should return empty object for no query string', () => {
        const params = UriQueryParser.parse('https://example.com/path');

        expect(Object.keys(params).length).assertEqual(0);
      });

      it('should handle empty values', () => {
        const params = UriQueryParser.parse('https://example.com?key=');

        expect(params['key']).assertEqual('');
      });
    });

    describe('build', () => {
      it('should build query string from params', () => {
        const query = UriQueryParser.build({ foo: 'bar', count: 42, active: true });

        expect(query).toContain('foo=bar');
        expect(query).toContain('count=42');
        expect(query).toContain('active=true');
        expect(query.startsWith('?')).assertTrue();
      });

      it('should URL encode values', () => {
        const query = UriQueryParser.build({ name: 'John Doe', email: 'test@example.com' });

        expect(query).toContain('name=John%20Doe');
        expect(query).toContain('email=test%40example.com');
      });

      it('should return empty string for empty params', () => {
        const query = UriQueryParser.build({});

        expect(query).assertEqual('');
      });
    });
  });
}
