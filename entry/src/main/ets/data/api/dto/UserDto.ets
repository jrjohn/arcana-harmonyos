import { User, PaginatedUsers, CreateUserRequest, UpdateUserRequest, UserImpl } from '../../../domain/models/User';

/**
 * Data Transfer Object for User from the API
 */
export interface UserDto {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  avatar: string;
}

/**
 * Support info from API response
 */
export interface SupportInfo {
  url: string;
  text: string;
}

/**
 * API response for paginated users
 */
export interface PaginatedUsersResponse {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
  data: UserDto[];
  support?: SupportInfo;
}

/**
 * API response for a single user
 */
export interface SingleUserResponse {
  data: UserDto;
  support?: SupportInfo;
}

/**
 * Request body for creating a user
 */
export interface CreateUserRequestDto {
  email: string;
  first_name: string;
  last_name: string;
  avatar?: string;
}

/**
 * Request body for updating a user
 */
export interface UpdateUserRequestDto {
  email?: string;
  first_name?: string;
  last_name?: string;
  avatar?: string;
}

/**
 * Response from create user API
 */
export interface CreateUserResponseDto {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  avatar?: string;
  createdAt: string;
}

/**
 * Response from update user API
 */
export interface UpdateUserResponseDto {
  email?: string;
  first_name?: string;
  last_name?: string;
  avatar?: string;
  updatedAt: string;
}

/**
 * Mapper class for converting between DTOs and domain models
 */
export class UserDtoMapper {
  /**
   * Converts a UserDto to a domain User
   */
  static toDomain(dto: UserDto): User {
    return UserImpl.create(
      dto.id,
      dto.email,
      dto.first_name,
      dto.last_name,
      dto.avatar
    );
  }

  /**
   * Converts a PaginatedUsersResponse to domain PaginatedUsers
   */
  static toPaginatedDomain(response: PaginatedUsersResponse): PaginatedUsers {
    const users: User[] = [];
    for (const dto of response.data) {
      users.push(UserDtoMapper.toDomain(dto));
    }
    const result: PaginatedUsers = {
      users: users,
      page: response.page,
      perPage: response.per_page,
      total: response.total,
      totalPages: response.total_pages
    };
    return result;
  }

  /**
   * Converts a CreateUserRequest to a CreateUserRequestDto
   */
  static toCreateDto(request: CreateUserRequest): CreateUserRequestDto {
    const dto: CreateUserRequestDto = {
      email: request.email,
      first_name: request.firstName,
      last_name: request.lastName,
      avatar: request.avatar !== '' ? request.avatar : undefined
    };
    return dto;
  }

  /**
   * Converts an UpdateUserRequest to an UpdateUserRequestDto
   */
  static toUpdateDto(request: UpdateUserRequest): UpdateUserRequestDto {
    const dto: UpdateUserRequestDto = {
      email: request.email,
      first_name: request.firstName,
      last_name: request.lastName,
      avatar: request.avatar !== '' ? request.avatar : undefined
    };
    return dto;
  }

  /**
   * Converts a CreateUserResponseDto to a domain User
   */
  static createResponseToDomain(response: CreateUserResponseDto, request: CreateUserRequest): User {
    return UserImpl.create(
      parseInt(response.id, 10),
      response.email !== undefined ? response.email : request.email,
      response.first_name !== undefined ? response.first_name : request.firstName,
      response.last_name !== undefined ? response.last_name : request.lastName,
      response.avatar !== undefined ? response.avatar : (request.avatar !== undefined ? request.avatar : '')
    );
  }

  /**
   * Converts an UpdateUserResponseDto to a domain User
   */
  static updateResponseToDomain(response: UpdateUserResponseDto, request: UpdateUserRequest): User {
    return UserImpl.create(
      request.id,
      response.email !== undefined ? response.email : request.email,
      response.first_name !== undefined ? response.first_name : request.firstName,
      response.last_name !== undefined ? response.last_name : request.lastName,
      response.avatar !== undefined ? response.avatar : (request.avatar !== undefined ? request.avatar : '')
    );
  }
}
