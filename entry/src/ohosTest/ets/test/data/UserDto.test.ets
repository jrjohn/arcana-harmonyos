/**
 * Unit Tests for UserDto and UserDtoMapper
 */

import { describe, it, expect } from '@ohos/hypium';
import {
  UserDto,
  SupportInfo,
  PaginatedUsersResponse,
  SingleUserResponse,
  CreateUserRequestDto,
  UpdateUserRequestDto,
  CreateUserResponseDto,
  UpdateUserResponseDto,
  UserDtoMapper
} from '../../../../main/ets/data/api/dto/UserDto';
import { CreateUserRequest, UpdateUserRequest } from '../../../../main/ets/domain/models/User';

export default function UserDtoTest() {
  describe('UserDtoMapper', () => {
    describe('toDomain', () => {
      it('should convert UserDto to User domain model', () => {
        const dto: UserDto = {
          id: 1,
          email: 'george.bluth@reqres.in',
          first_name: 'George',
          last_name: 'Bluth',
          avatar: 'https://reqres.in/img/faces/1-image.jpg'
        };

        const user = UserDtoMapper.toDomain(dto);

        expect(user.id).assertEqual(1);
        expect(user.email).assertEqual('george.bluth@reqres.in');
        expect(user.firstName).assertEqual('George');
        expect(user.lastName).assertEqual('Bluth');
        expect(user.avatar).assertEqual('https://reqres.in/img/faces/1-image.jpg');
      });

      it('should handle empty strings in UserDto', () => {
        const dto: UserDto = {
          id: 2,
          email: '',
          first_name: '',
          last_name: '',
          avatar: ''
        };

        const user = UserDtoMapper.toDomain(dto);

        expect(user.id).assertEqual(2);
        expect(user.email).assertEqual('');
        expect(user.firstName).assertEqual('');
        expect(user.lastName).assertEqual('');
        expect(user.avatar).assertEqual('');
      });

      it('should handle special characters in names', () => {
        const dto: UserDto = {
          id: 3,
          email: 'test@example.com',
          first_name: "O'Brien",
          last_name: 'García-López',
          avatar: 'https://example.com/avatar.jpg'
        };

        const user = UserDtoMapper.toDomain(dto);

        expect(user.firstName).assertEqual("O'Brien");
        expect(user.lastName).assertEqual('García-López');
      });
    });

    describe('toPaginatedDomain', () => {
      it('should convert PaginatedUsersResponse to PaginatedUsers', () => {
        const response: PaginatedUsersResponse = {
          page: 1,
          per_page: 6,
          total: 12,
          total_pages: 2,
          data: [
            {
              id: 1,
              email: 'george.bluth@reqres.in',
              first_name: 'George',
              last_name: 'Bluth',
              avatar: 'https://reqres.in/img/faces/1-image.jpg'
            },
            {
              id: 2,
              email: 'janet.weaver@reqres.in',
              first_name: 'Janet',
              last_name: 'Weaver',
              avatar: 'https://reqres.in/img/faces/2-image.jpg'
            }
          ]
        };

        const paginatedUsers = UserDtoMapper.toPaginatedDomain(response);

        expect(paginatedUsers.page).assertEqual(1);
        expect(paginatedUsers.perPage).assertEqual(6);
        expect(paginatedUsers.total).assertEqual(12);
        expect(paginatedUsers.totalPages).assertEqual(2);
        expect(paginatedUsers.users.length).assertEqual(2);
        expect(paginatedUsers.users[0].firstName).assertEqual('George');
        expect(paginatedUsers.users[1].firstName).assertEqual('Janet');
      });

      it('should handle empty data array', () => {
        const response: PaginatedUsersResponse = {
          page: 1,
          per_page: 6,
          total: 0,
          total_pages: 0,
          data: []
        };

        const paginatedUsers = UserDtoMapper.toPaginatedDomain(response);

        expect(paginatedUsers.users.length).assertEqual(0);
        expect(paginatedUsers.total).assertEqual(0);
        expect(paginatedUsers.totalPages).assertEqual(0);
      });

      it('should handle response with support info', () => {
        const response: PaginatedUsersResponse = {
          page: 1,
          per_page: 6,
          total: 1,
          total_pages: 1,
          data: [
            {
              id: 1,
              email: 'test@test.com',
              first_name: 'Test',
              last_name: 'User',
              avatar: 'https://example.com/avatar.jpg'
            }
          ],
          support: {
            url: 'https://reqres.in/#support-heading',
            text: 'Support text'
          }
        };

        const paginatedUsers = UserDtoMapper.toPaginatedDomain(response);

        expect(paginatedUsers.users.length).assertEqual(1);
      });

      it('should correctly map all users in data array', () => {
        const response: PaginatedUsersResponse = {
          page: 2,
          per_page: 3,
          total: 9,
          total_pages: 3,
          data: [
            { id: 4, email: 'user4@test.com', first_name: 'User', last_name: 'Four', avatar: 'a4.jpg' },
            { id: 5, email: 'user5@test.com', first_name: 'User', last_name: 'Five', avatar: 'a5.jpg' },
            { id: 6, email: 'user6@test.com', first_name: 'User', last_name: 'Six', avatar: 'a6.jpg' }
          ]
        };

        const paginatedUsers = UserDtoMapper.toPaginatedDomain(response);

        expect(paginatedUsers.users.length).assertEqual(3);
        expect(paginatedUsers.users[0].id).assertEqual(4);
        expect(paginatedUsers.users[1].id).assertEqual(5);
        expect(paginatedUsers.users[2].id).assertEqual(6);
      });
    });

    describe('toCreateDto', () => {
      it('should convert CreateUserRequest to CreateUserRequestDto', () => {
        const request: CreateUserRequest = {
          email: 'new.user@test.com',
          firstName: 'New',
          lastName: 'User',
          avatar: 'https://example.com/avatar.jpg'
        };

        const dto = UserDtoMapper.toCreateDto(request);

        expect(dto.email).assertEqual('new.user@test.com');
        expect(dto.first_name).assertEqual('New');
        expect(dto.last_name).assertEqual('User');
        expect(dto.avatar).assertEqual('https://example.com/avatar.jpg');
      });

      it('should set avatar to undefined for empty string', () => {
        const request: CreateUserRequest = {
          email: 'new.user@test.com',
          firstName: 'New',
          lastName: 'User',
          avatar: ''
        };

        const dto = UserDtoMapper.toCreateDto(request);

        expect(dto.avatar).assertUndefined();
      });

      it('should preserve avatar when not empty', () => {
        const request: CreateUserRequest = {
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: 'http://avatar.url'
        };

        const dto = UserDtoMapper.toCreateDto(request);

        expect(dto.avatar).assertEqual('http://avatar.url');
      });
    });

    describe('toUpdateDto', () => {
      it('should convert UpdateUserRequest to UpdateUserRequestDto', () => {
        const request: UpdateUserRequest = {
          id: 1,
          email: 'updated@test.com',
          firstName: 'Updated',
          lastName: 'User',
          avatar: 'https://example.com/new-avatar.jpg'
        };

        const dto = UserDtoMapper.toUpdateDto(request);

        expect(dto.email).assertEqual('updated@test.com');
        expect(dto.first_name).assertEqual('Updated');
        expect(dto.last_name).assertEqual('User');
        expect(dto.avatar).assertEqual('https://example.com/new-avatar.jpg');
      });

      it('should set avatar to undefined for empty string', () => {
        const request: UpdateUserRequest = {
          id: 1,
          email: 'updated@test.com',
          firstName: 'Updated',
          lastName: 'User',
          avatar: ''
        };

        const dto = UserDtoMapper.toUpdateDto(request);

        expect(dto.avatar).assertUndefined();
      });

      it('should not include id in the DTO', () => {
        const request: UpdateUserRequest = {
          id: 99,
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: 'avatar.jpg'
        };

        const dto = UserDtoMapper.toUpdateDto(request);

        // The DTO should not have an id property
        expect((dto as Object).hasOwnProperty('id')).assertFalse();
      });
    });

    describe('createResponseToDomain', () => {
      it('should convert CreateUserResponseDto to User domain model', () => {
        const response: CreateUserResponseDto = {
          id: '100',
          email: 'new@test.com',
          first_name: 'New',
          last_name: 'User',
          avatar: 'https://example.com/avatar.jpg',
          createdAt: '2023-12-25T10:00:00.000Z'
        };
        const request: CreateUserRequest = {
          email: 'new@test.com',
          firstName: 'New',
          lastName: 'User',
          avatar: 'https://example.com/avatar.jpg'
        };

        const user = UserDtoMapper.createResponseToDomain(response, request);

        expect(user.id).assertEqual(100);
        expect(user.email).assertEqual('new@test.com');
        expect(user.firstName).assertEqual('New');
        expect(user.lastName).assertEqual('User');
        expect(user.avatar).assertEqual('https://example.com/avatar.jpg');
      });

      it('should use request values when response fields are undefined', () => {
        const response: CreateUserResponseDto = {
          id: '101',
          email: undefined as unknown as string,
          first_name: undefined as unknown as string,
          last_name: undefined as unknown as string,
          avatar: undefined,
          createdAt: '2023-12-25T10:00:00.000Z'
        };
        const request: CreateUserRequest = {
          email: 'fallback@test.com',
          firstName: 'Fallback',
          lastName: 'User',
          avatar: 'fallback-avatar.jpg'
        };

        const user = UserDtoMapper.createResponseToDomain(response, request);

        expect(user.email).assertEqual('fallback@test.com');
        expect(user.firstName).assertEqual('Fallback');
        expect(user.lastName).assertEqual('User');
        expect(user.avatar).assertEqual('fallback-avatar.jpg');
      });

      it('should parse string ID to number', () => {
        const response: CreateUserResponseDto = {
          id: '999',
          email: 'test@test.com',
          first_name: 'Test',
          last_name: 'User',
          createdAt: '2023-12-25T10:00:00.000Z'
        };
        const request: CreateUserRequest = {
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: ''
        };

        const user = UserDtoMapper.createResponseToDomain(response, request);

        expect(user.id).assertEqual(999);
        expect(typeof user.id === 'number').assertTrue();
      });

      it('should handle empty avatar in request when response avatar is undefined', () => {
        const response: CreateUserResponseDto = {
          id: '102',
          email: 'test@test.com',
          first_name: 'Test',
          last_name: 'User',
          avatar: undefined,
          createdAt: '2023-12-25T10:00:00.000Z'
        };
        const request: CreateUserRequest = {
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: ''
        };

        const user = UserDtoMapper.createResponseToDomain(response, request);

        expect(user.avatar).assertEqual('');
      });
    });

    describe('updateResponseToDomain', () => {
      it('should convert UpdateUserResponseDto to User domain model', () => {
        const response: UpdateUserResponseDto = {
          email: 'updated@test.com',
          first_name: 'Updated',
          last_name: 'User',
          avatar: 'https://example.com/updated-avatar.jpg',
          updatedAt: '2023-12-25T12:00:00.000Z'
        };
        const request: UpdateUserRequest = {
          id: 1,
          email: 'old@test.com',
          firstName: 'Old',
          lastName: 'User',
          avatar: 'https://example.com/old-avatar.jpg'
        };

        const user = UserDtoMapper.updateResponseToDomain(response, request);

        expect(user.id).assertEqual(1);
        expect(user.email).assertEqual('updated@test.com');
        expect(user.firstName).assertEqual('Updated');
        expect(user.lastName).assertEqual('User');
        expect(user.avatar).assertEqual('https://example.com/updated-avatar.jpg');
      });

      it('should use request values when response fields are undefined', () => {
        const response: UpdateUserResponseDto = {
          email: undefined,
          first_name: undefined,
          last_name: undefined,
          avatar: undefined,
          updatedAt: '2023-12-25T12:00:00.000Z'
        };
        const request: UpdateUserRequest = {
          id: 5,
          email: 'request@test.com',
          firstName: 'Request',
          lastName: 'User',
          avatar: 'request-avatar.jpg'
        };

        const user = UserDtoMapper.updateResponseToDomain(response, request);

        expect(user.id).assertEqual(5);
        expect(user.email).assertEqual('request@test.com');
        expect(user.firstName).assertEqual('Request');
        expect(user.lastName).assertEqual('User');
        expect(user.avatar).assertEqual('request-avatar.jpg');
      });

      it('should preserve request ID in the result', () => {
        const response: UpdateUserResponseDto = {
          email: 'new@test.com',
          first_name: 'New',
          last_name: 'Name',
          updatedAt: '2023-12-25T12:00:00.000Z'
        };
        const request: UpdateUserRequest = {
          id: 42,
          email: 'old@test.com',
          firstName: 'Old',
          lastName: 'Name',
          avatar: ''
        };

        const user = UserDtoMapper.updateResponseToDomain(response, request);

        expect(user.id).assertEqual(42);
      });

      it('should handle empty avatar in request when response avatar is undefined', () => {
        const response: UpdateUserResponseDto = {
          email: 'test@test.com',
          first_name: 'Test',
          last_name: 'User',
          avatar: undefined,
          updatedAt: '2023-12-25T12:00:00.000Z'
        };
        const request: UpdateUserRequest = {
          id: 1,
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: ''
        };

        const user = UserDtoMapper.updateResponseToDomain(response, request);

        expect(user.avatar).assertEqual('');
      });

      it('should use response avatar when defined', () => {
        const response: UpdateUserResponseDto = {
          avatar: 'new-avatar.jpg',
          updatedAt: '2023-12-25T12:00:00.000Z'
        };
        const request: UpdateUserRequest = {
          id: 1,
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: 'old-avatar.jpg'
        };

        const user = UserDtoMapper.updateResponseToDomain(response, request);

        expect(user.avatar).assertEqual('new-avatar.jpg');
      });
    });
  });

  describe('DTO Interfaces', () => {
    describe('UserDto', () => {
      it('should allow creating valid UserDto object', () => {
        const dto: UserDto = {
          id: 1,
          email: 'test@test.com',
          first_name: 'Test',
          last_name: 'User',
          avatar: 'avatar.jpg'
        };

        expect(dto.id).assertEqual(1);
        expect(dto.email).assertEqual('test@test.com');
      });
    });

    describe('SupportInfo', () => {
      it('should allow creating valid SupportInfo object', () => {
        const support: SupportInfo = {
          url: 'https://reqres.in/#support-heading',
          text: 'Support text here'
        };

        expect(support.url).assertEqual('https://reqres.in/#support-heading');
        expect(support.text).assertEqual('Support text here');
      });
    });

    describe('SingleUserResponse', () => {
      it('should allow creating valid SingleUserResponse object', () => {
        const response: SingleUserResponse = {
          data: {
            id: 1,
            email: 'test@test.com',
            first_name: 'Test',
            last_name: 'User',
            avatar: 'avatar.jpg'
          }
        };

        expect(response.data.id).assertEqual(1);
      });

      it('should allow optional support field', () => {
        const response: SingleUserResponse = {
          data: {
            id: 1,
            email: 'test@test.com',
            first_name: 'Test',
            last_name: 'User',
            avatar: 'avatar.jpg'
          },
          support: {
            url: 'https://example.com',
            text: 'Support'
          }
        };

        expect(response.support?.url).assertEqual('https://example.com');
      });
    });

    describe('CreateUserRequestDto', () => {
      it('should allow creating valid CreateUserRequestDto', () => {
        const dto: CreateUserRequestDto = {
          email: 'new@test.com',
          first_name: 'New',
          last_name: 'User',
          avatar: 'avatar.jpg'
        };

        expect(dto.email).assertEqual('new@test.com');
        expect(dto.avatar).assertEqual('avatar.jpg');
      });

      it('should allow optional avatar', () => {
        const dto: CreateUserRequestDto = {
          email: 'new@test.com',
          first_name: 'New',
          last_name: 'User'
        };

        expect(dto.avatar).assertUndefined();
      });
    });

    describe('UpdateUserRequestDto', () => {
      it('should allow creating UpdateUserRequestDto with all optional fields', () => {
        const dto: UpdateUserRequestDto = {};

        expect(dto.email).assertUndefined();
        expect(dto.first_name).assertUndefined();
        expect(dto.last_name).assertUndefined();
        expect(dto.avatar).assertUndefined();
      });

      it('should allow partial updates', () => {
        const dto: UpdateUserRequestDto = {
          email: 'updated@test.com'
        };

        expect(dto.email).assertEqual('updated@test.com');
        expect(dto.first_name).assertUndefined();
      });
    });

    describe('CreateUserResponseDto', () => {
      it('should allow creating valid CreateUserResponseDto', () => {
        const dto: CreateUserResponseDto = {
          id: '100',
          email: 'new@test.com',
          first_name: 'New',
          last_name: 'User',
          avatar: 'avatar.jpg',
          createdAt: '2023-12-25T10:00:00.000Z'
        };

        expect(dto.id).assertEqual('100');
        expect(dto.createdAt).assertEqual('2023-12-25T10:00:00.000Z');
      });
    });

    describe('UpdateUserResponseDto', () => {
      it('should allow creating valid UpdateUserResponseDto', () => {
        const dto: UpdateUserResponseDto = {
          email: 'updated@test.com',
          first_name: 'Updated',
          last_name: 'User',
          avatar: 'new-avatar.jpg',
          updatedAt: '2023-12-25T12:00:00.000Z'
        };

        expect(dto.updatedAt).assertEqual('2023-12-25T12:00:00.000Z');
      });
    });
  });
}
