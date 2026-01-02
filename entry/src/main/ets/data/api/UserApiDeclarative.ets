/**
 * UserApiDeclarative - Example of Declarative API Definition
 *
 * Demonstrates how to define REST APIs using the declarative HTTP client,
 * similar to Retrofit/Ktorfit style but compatible with ArkTS limitations.
 *
 * Compare with traditional UserApiServiceImpl to see the reduction in boilerplate.
 */

import { ApiClient, ApiClientBuilder } from '../../core/http/ApiClient';
import { Endpoint, ExecutableEndpoint, ExecutableEndpointWithBody, ExecutableVoidEndpoint } from '../../core/http/ApiEndpoint';
import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers, PaginatedUsersImpl, UserImpl } from '../../domain/models/User';
import {
  PaginatedUsersResponse,
  SingleUserResponse,
  CreateUserRequestDto,
  UpdateUserRequestDto,
  CreateUserResponseDto,
  UpdateUserResponseDto,
  UserDto
} from './dto/UserDto';
import { Result, ResultFactory, Success } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';
import { ApiConfig, ApiHeaders } from './ApiConfig';

/**
 * Response mappers - Convert raw API responses to domain models
 */
class UserResponseMappers {
  /**
   * Maps raw paginated response to domain model
   */
  static mapPaginatedUsers(raw: Object): PaginatedUsers {
    const response = raw as PaginatedUsersResponse;
    const users: User[] = [];
    for (const dto of response.data) {
      users.push(UserResponseMappers.mapUserDto(dto));
    }
    return new PaginatedUsersImpl(
      users,
      response.page,
      response.per_page,
      response.total,
      response.total_pages
    );
  }

  /**
   * Maps single user response to domain model
   */
  static mapSingleUser(raw: Object): User {
    const response = raw as SingleUserResponse;
    return UserResponseMappers.mapUserDto(response.data);
  }

  /**
   * Maps UserDto to domain User
   */
  static mapUserDto(dto: UserDto): User {
    return new UserImpl(
      dto.id,
      dto.email,
      dto.first_name,
      dto.last_name,
      dto.avatar
    );
  }

  /**
   * Maps create response to domain model
   */
  static mapCreateResponse(raw: Object, request: CreateUserRequest): User {
    const response = raw as CreateUserResponseDto;
    return new UserImpl(
      parseInt(response.id, 10),
      response.email || request.email,
      response.first_name || request.firstName,
      response.last_name || request.lastName,
      response.avatar || request.avatar || ''
    );
  }

  /**
   * Maps update response to domain model
   */
  static mapUpdateResponse(raw: Object, request: UpdateUserRequest): User {
    const response = raw as UpdateUserResponseDto;
    return new UserImpl(
      request.id,
      response.email || request.email,
      response.first_name || request.firstName,
      response.last_name || request.lastName,
      response.avatar || request.avatar || ''
    );
  }
}

/**
 * Declarative API Definition for User endpoints
 *
 * This class defines all User-related API endpoints in a declarative style.
 * Each endpoint is defined once and can be executed multiple times.
 */
export class UserApi {
  private client: ApiClient;

  // ===== Endpoint Definitions (Declarative) =====

  /**
   * GET /users?page={page}&per_page={perPage}
   * Returns paginated list of users
   */
  private getUsersEndpoint: ExecutableEndpoint<PaginatedUsers> = Endpoint
    .get<PaginatedUsers>('/users')
    .queryParam('page')
    .queryParam('per_page')
    .mapResponse(UserResponseMappers.mapPaginatedUsers)
    .build();

  /**
   * GET /users/{id}
   * Returns a single user by ID
   */
  private getUserEndpoint: ExecutableEndpoint<User> = Endpoint
    .get<User>('/users/{id}')
    .pathParam('id')
    .mapResponse(UserResponseMappers.mapSingleUser)
    .build();

  /**
   * POST /users
   * Creates a new user
   */
  private createUserEndpoint: ExecutableEndpointWithBody<CreateUserRequestDto, Object> = Endpoint
    .post<CreateUserRequestDto, Object>('/users')
    .mapResponse((raw) => raw) // Raw response, will be mapped with request context
    .build();

  /**
   * PUT /users/{id}
   * Updates an existing user
   */
  private updateUserEndpoint: ExecutableEndpointWithBody<UpdateUserRequestDto, Object> = Endpoint
    .put<UpdateUserRequestDto, Object>('/users/{id}')
    .pathParam('id')
    .mapResponse((raw) => raw) // Raw response, will be mapped with request context
    .build();

  /**
   * DELETE /users/{id}
   * Deletes a user
   */
  private deleteUserEndpoint: ExecutableVoidEndpoint = Endpoint
    .delete('/users/{id}')
    .pathParam('id')
    .build();

  /**
   * Creates the UserApi with configured client
   */
  constructor() {
    this.client = ApiClient.create(ApiConfig.BASE_URL)
      .setTimeout(ApiConfig.TIMEOUT)
      .addHeader('Content-Type', ApiHeaders.CONTENT_TYPE)
      .addHeader('Accept', ApiHeaders.ACCEPT)
      .apiKey(ApiHeaders.API_KEY_HEADER, ApiConfig.API_KEY)
      .logging(true)
      .build();
  }

  /**
   * Factory method for creating UserApi
   */
  static create(): UserApi {
    return new UserApi();
  }

  // ===== Public API Methods =====

  /**
   * Fetches paginated users
   */
  async getUsers(page: number = 1, perPage: number = 6): Promise<Result<PaginatedUsers, AppError>> {
    const queryParams = new Map<string, string>();
    queryParams.set('page', page.toString());
    queryParams.set('per_page', perPage.toString());

    return this.getUsersEndpoint.execute(this.client, new Map(), queryParams);
  }

  /**
   * Fetches a single user by ID
   */
  async getUser(userId: number): Promise<Result<User, AppError>> {
    const pathParams = new Map<string, string>();
    pathParams.set('id', userId.toString());

    return this.getUserEndpoint.execute(this.client, pathParams);
  }

  /**
   * Creates a new user
   */
  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    const dto: CreateUserRequestDto = {
      email: request.email,
      first_name: request.firstName,
      last_name: request.lastName,
      avatar: request.avatar || undefined
    };

    const result = await this.createUserEndpoint.execute(this.client, dto);

    // Map the raw response with request context
    if (ResultFactory.isSuccess(result)) {
      const success = result as Success<Object>;
      const user = UserResponseMappers.mapCreateResponse(success.value, request);
      return ResultFactory.success(user);
    }

    return result as Result<User, AppError>;
  }

  /**
   * Updates an existing user
   */
  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    const pathParams = new Map<string, string>();
    pathParams.set('id', request.id.toString());

    const dto: UpdateUserRequestDto = {
      email: request.email,
      first_name: request.firstName,
      last_name: request.lastName,
      avatar: request.avatar || undefined
    };

    const result = await this.updateUserEndpoint.execute(this.client, dto, pathParams);

    // Map the raw response with request context
    if (ResultFactory.isSuccess(result)) {
      const success = result as Success<Object>;
      const user = UserResponseMappers.mapUpdateResponse(success.value, request);
      return ResultFactory.success(user);
    }

    return result as Result<User, AppError>;
  }

  /**
   * Deletes a user
   */
  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    const pathParams = new Map<string, string>();
    pathParams.set('id', userId.toString());

    return this.deleteUserEndpoint.execute(this.client, pathParams);
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    this.client.destroy();
  }
}

/**
 * Comparison: Traditional vs Declarative
 *
 * TRADITIONAL (UserApiServiceImpl):
 * ```
 * async getUsers(page: number = 1, perPage: number = 6): Promise<Result<PaginatedUsers, AppError>> {
 *   const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}?page=${page}&per_page=${perPage}`;
 *   try {
 *     const response = await this.httpClient.request(url, {
 *       method: http.RequestMethod.GET,
 *       header: this.getHeaders(),
 *       connectTimeout: ApiConfig.TIMEOUT,
 *       readTimeout: ApiConfig.TIMEOUT
 *     });
 *     if (response.responseCode === HttpStatus.OK) {
 *       const data = JSON.parse(response.result as string) as PaginatedUsersResponse;
 *       return ResultFactory.success(UserDtoMapper.toPaginatedDomain(data));
 *     } else {
 *       return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
 *     }
 *   } catch (error) {
 *     return ResultFactory.failure(this.handleError(error));
 *   }
 * }
 * ```
 *
 * DECLARATIVE (This file):
 * ```
 * // Define once
 * private getUsersEndpoint = Endpoint.get<PaginatedUsers>('/users')
 *   .queryParam('page').queryParam('per_page')
 *   .mapResponse(UserResponseMappers.mapPaginatedUsers)
 *   .build();
 *
 * // Execute
 * async getUsers(page: number = 1, perPage: number = 6) {
 *   return this.getUsersEndpoint.execute(this.client, new Map(), queryParams);
 * }
 * ```
 *
 * Benefits:
 * 1. Less boilerplate - endpoint definition is declarative
 * 2. Separation of concerns - mappers are explicit and reusable
 * 3. Type safety - generics enforce correct types
 * 4. Consistency - all endpoints follow the same pattern
 * 5. Testability - endpoints can be mocked easily
 */
